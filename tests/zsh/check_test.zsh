#! /usr/bin/env zsh
# zsh/check.zsh の _dotfiles_check_nix_upstream_daily を検証する。
#
#   zsh tests/zsh/check_test.zsh
#
# git はスタブに差し替え、呼び出し引数を記録して検証する。ネットワークへは出ない。
# 検証対象は「flake.lock のどのノードを何回・どの ref 指定で問い合わせるか」。
# ref を裸の名前で渡すと ref の多いリポジトリで全列挙が走り、起動が数分ブロックされる。

DOTFILES=${0:A:h:h:h}

pass_count=0
fail_count=0

pass() {
  pass_count=$((pass_count + 1))
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL  %s\n' "$1"
}

# assert_eq <期待値> <実際値> <ラベル>
assert_eq() {
  if [[ "$1" == "$2" ]]; then
    pass
  else
    fail "$3: expected=$1 actual=$2"
  fi
}

# assert_contains <期待する部分文字列> <対象> <ラベル>
assert_contains() {
  case "$2" in
    *"$1"*) pass ;;
    *) fail "$3: expected to contain=$1 actual=$2" ;;
  esac
}

# assert_not_contains <含まれてはいけない部分文字列> <対象> <ラベル>
assert_not_contains() {
  case "$2" in
    *"$1"*) fail "$3: expected NOT to contain=$1 actual=$2" ;;
    *) pass ;;
  esac
}

tmp=$(mktemp -d)
trap 'rm -r "$tmp"' EXIT

# flake.lock の fixture。
#   nixpkgs / nixpkgs_2 : 同一 owner/repo/ref の重複ノード（dedupe の対象）
#   dwt                 : ref が tag
#   ax                  : original.ref なし
#   local-src           : github 以外（問い合わせ対象外）
mkdir -p "$tmp/repo"
cat > "$tmp/repo/flake.lock" <<'LOCK'
{
  "nodes": {
    "nixpkgs": {
      "locked": { "type": "github", "owner": "nixos", "repo": "nixpkgs", "rev": "aaa" },
      "original": { "owner": "nixos", "repo": "nixpkgs", "ref": "nixpkgs-26.05-darwin" }
    },
    "nixpkgs_2": {
      "locked": { "type": "github", "owner": "nixos", "repo": "nixpkgs", "rev": "aaa" },
      "original": { "owner": "nixos", "repo": "nixpkgs", "ref": "nixpkgs-26.05-darwin" }
    },
    "dwt": {
      "locked": { "type": "github", "owner": "wao3299", "repo": "dwt", "rev": "aaa" },
      "original": { "owner": "wao3299", "repo": "dwt", "ref": "v0.2.0" }
    },
    "ax": {
      "locked": { "type": "github", "owner": "yusukebe", "repo": "ax", "rev": "aaa" },
      "original": { "owner": "yusukebe", "repo": "ax" }
    },
    "local-src": {
      "locked": { "type": "path", "path": "./ai-tools" }
    },
    "root": { "inputs": {} }
  },
  "root": "root",
  "version": 7
}
LOCK

# スタブ。呼び出し引数を 1 行 1 回で記録し、STUB_REV を rev として返す。
mkdir -p "$tmp/bin"
cat > "$tmp/bin/git" <<'STUB'
#! /bin/sh
printf '%s\n' "$*" >> "$STUB_CALLS"
[ -n "$STUB_REV" ] || exit 0
printf '%s\trefs/heads/stub\n' "$STUB_REV"
STUB
chmod +x "$tmp/bin/git"

export STUB_CALLS="$tmp/calls"
path=("$tmp/bin" $path)
rehash

# 自動実行を抑止して関数定義だけ読み込む
DOTFILES_CHECK_NO_AUTORUN=1 source "$DOTFILES/zsh/check.zsh"

# --- ケース1: locked と remote が同一 → 更新なし。問い合わせは dedupe される ---
: > "$STUB_CALLS"
export STUB_REV=aaa
out=$(_dotfiles_check_nix_upstream_daily "$tmp/repo")

assert_eq "" "$out" "同一 rev なら出力なし"
assert_eq 3 "$(grep -c . "$STUB_CALLS")" "重複ノードを dedupe して 3 リポジトリのみ問い合わせる"

calls=$(cat "$STUB_CALLS")
assert_contains "refs/heads/nixpkgs-26.05-darwin" "$calls" "branch ref をフルパスで渡す"
assert_contains "refs/tags/nixpkgs-26.05-darwin" "$calls" "tag 側もフルパスで併せて渡す"
assert_contains "refs/tags/v0.2.0" "$calls" "tag ref をフルパスで渡す"
assert_not_contains " nixpkgs-26.05-darwin" "$calls" "裸の ref 名は渡さない"
assert_contains "https://github.com/yusukebe/ax.git HEAD" "$calls" "original.ref なしは HEAD を渡す"
assert_not_contains "ai-tools" "$calls" "github 以外のノードは問い合わせない"

# --- ケース2: remote が locked と異なる → 更新ありを報告 ---
: > "$STUB_CALLS"
export STUB_REV=zzz
out=$(_dotfiles_check_nix_upstream_daily "$tmp/repo")
assert_contains "nix flake update" "$out" "rev が異なれば更新を報告する"

# --- ケース3: ls-remote が空を返す → 更新なし扱い ---
: > "$STUB_CALLS"
export STUB_REV=
out=$(_dotfiles_check_nix_upstream_daily "$tmp/repo")
assert_eq "" "$out" "remote が取れないときは報告しない"

# --- ケース4: flake.lock がない → 何もしない ---
: > "$STUB_CALLS"
out=$(_dotfiles_check_nix_upstream_daily "$tmp/missing")
assert_eq "" "$out" "flake.lock がなければ出力なし"
assert_eq 0 "$(grep -c . "$STUB_CALLS")" "flake.lock がなければ呼び出しなし"

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
[[ $fail_count -eq 0 ]]
