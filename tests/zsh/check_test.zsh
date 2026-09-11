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
# STUB_EMPTY_FOR に指定したオプションを含む呼び出しだけは空を返す。branch を
# 引いて空だったときに tag へフォールバックする経路を再現するため。
mkdir -p "$tmp/bin"
cat > "$tmp/bin/git" <<'STUB'
#! /bin/sh
printf '%s\n' "$*" >> "$STUB_CALLS"
if [ -n "$STUB_EMPTY_FOR" ]; then
  case " $* " in
    *" $STUB_EMPTY_FOR "*) exit 0 ;;
  esac
fi
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
export STUB_EMPTY_FOR=
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

# --- ケース5: daily 群はバックグラウンドで走り、結果を次回表示用に書き出す ---
# ここから先は各 daily 関数をスタブへ差し替えるので、上のケースより後に置く。
_dotfiles_check_nix_daily()          { print -r -- "nix     → dummy-nix" }
_dotfiles_check_nix_upstream_daily() { return }
_dotfiles_check_sheldon_daily()      { print -r -- "sheldon → dummy-sheldon" }
_dotfiles_check_brew_daily()         { return }

mkdir -p "$tmp/cache"
_dotfiles_check_daily_async "$tmp/repo" "$tmp/cache" 2026-09-11
result=$(cat "$tmp/cache/dotfiles-check-result" 2>/dev/null)

assert_contains "2026-09-11" "$result" "いつ走ったチェックか分かる"
assert_contains "nix-upstream" "$result" "遅いチェックの名前が残る"
assert_contains "sheldon" "$result" "全チェックの名前が残る"
assert_contains "brew" "$result" "結果を返さないチェックも名前が残る"
assert_contains "ms" "$result" "所要時間が残る"
assert_contains "dummy-nix" "$result" "更新メッセージを引き継ぐ"
assert_contains "dummy-sheldon" "$result" "複数の更新メッセージを引き継ぐ"

# cache の日付は同日の重複起動を防ぐため呼び出し側が先に書く。async 側では書かない
assert_eq "1" "$([[ -f "$tmp/cache/dotfiles-check-date" ]] && print 0 || print 1)" \
  "日付ファイルは async 側では書かない"

# --- ケース6: 更新が無ければ「更新が必要」を書かない ---
_dotfiles_check_nix_daily()     { return }
_dotfiles_check_sheldon_daily() { return }

rm -f "$tmp/cache/dotfiles-check-result"
_dotfiles_check_daily_async "$tmp/repo" "$tmp/cache" 2026-09-11
result=$(cat "$tmp/cache/dotfiles-check-result" 2>/dev/null)

assert_contains "nix-upstream" "$result" "更新が無くても所要時間は残す"
assert_not_contains "更新が必要" "$result" "更新が無ければ見出しを出さない"

printf '\n%d passed, %d failed\n' "$pass_count" "$fail_count"
[[ $fail_count -eq 0 ]]
