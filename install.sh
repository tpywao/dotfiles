#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")" && pwd -P)
. "$DOTFILES/utils/install-common.sh"
shell=${1:-$SHELL}

case $shell in
  *fish )
    # fish/ はディレクトリごと ~/.config/fish へリンクするため、fish/install.sh を
    # 置くとインストーラまでリンク先に配られる。ここでリンクする
    symlink $DOTFILES/fish ~/.config/fish
    ;;
  *zsh )
    sh "$DOTFILES/zsh/install.sh" || exit $?
    ;;
  *bash )
    symlink $DOTFILES/bashrc ~/.bashrc
    symlink $DOTFILES/aliases.bash ~/.aliases.bash
    ;;
esac

# 専用ディレクトリを持たない、リポジトリ直下の設定ファイル
symlink $DOTFILES/.editorconfig ~/.editorconfig
symlink $DOTFILES/vimrc ~/.vimrc
symlink $DOTFILES/tmux.conf ~/.tmux.conf
symlink $DOTFILES/screenrc ~/.screenrc
symlink $DOTFILES/sqliterc ~/.sqliterc
symlink $DOTFILES/direnvrc ~/.direnvrc

# fzf/ も fish/ と同じくディレクトリごとリンクするため、ここでリンクする
symlink $DOTFILES/fzf ~/.fzf

# 各ディレクトリの install.sh。それぞれ単体でも実行できる (例: ./git/install.sh)
for dir in git docker sheldon karabiner ghostty; do
  sh "$DOTFILES/$dir/install.sh" || exit $?
done

# Nix config
mkdir -p "$HOME/.config/nix"
symlink $DOTFILES/nix/nix.conf ~/.config/nix/nix.conf

# Nix + home-manager
if ! command -v nix > /dev/null 2>&1; then
  NIX_INSTALL_CMD="curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
  echo "Nix is not installed."
  echo "  $NIX_INSTALL_CMD"
  printf "Install now? [y/N] "
  read answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    eval "$NIX_INSTALL_CMD"
    # Load Nix into the current shell session after installation
    NIX_PROFILE="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
    [ -f "$NIX_PROFILE" ] && . "$NIX_PROFILE"
  else
    echo "Skipping Nix installation."
  fi
fi

if command -v nix > /dev/null 2>&1; then
  if [ -z "${DOTFILES_MACHINE:-}" ]; then
    # flake.nix の homeConfigurations から選択肢を列挙する
    # (`<machine> = mkHome ...;` の行をパース。nix eval は入力の fetch が要るため使わない)
    machines=$(sed -n 's/^[[:space:]]*\([A-Za-z0-9_-]*\)[[:space:]]*=[[:space:]]*mkHome[[:space:]].*/\1/p' "$DOTFILES/flake.nix")
    # 環境変数に無くても ~/.local/zsh/*.zsh に保存済みの値があればそれを使う
    # (bash からの実行や保存直後の再実行では環境変数に載らない。zsh の source と同じく後の export を有効値とする)
    saved_machine=$(sed -n "s/^[[:space:]]*export[[:space:]]\{1,\}DOTFILES_MACHINE=[\"']\{0,1\}\([A-Za-z0-9_-]*\).*/\1/p" "$HOME"/.local/zsh/*.zsh 2>/dev/null | tail -n 1)
    if [ -n "$saved_machine" ]; then
      for machine in $machines; do
        if [ "$saved_machine" = "$machine" ]; then
          DOTFILES_MACHINE=$saved_machine
          export DOTFILES_MACHINE
          echo "-----> Using DOTFILES_MACHINE=$DOTFILES_MACHINE (saved in ~/.local/zsh/*.zsh)"
          break
        fi
      done
      if [ -z "${DOTFILES_MACHINE:-}" ]; then
        echo "Note: saved DOTFILES_MACHINE=$saved_machine is not in flake.nix homeConfigurations. Ignoring it."
      fi
    fi
  fi
  if [ -z "${DOTFILES_MACHINE:-}" ]; then
    # 非対話実行 (パイプ・CI) では read がパイプ入力を消費・ブロックするため、メニューを出さず fail-fast
    if [ ! -t 0 ]; then
      echo "Error: DOTFILES_MACHINE is not set." >&2
      echo "  export DOTFILES_MACHINE=<machine> (flake.nix の homeConfigurations のエントリ名。詳細は nix/README.md)" >&2
      exit 1
    fi
    if [ -z "$machines" ]; then
      echo "Error: DOTFILES_MACHINE is not set, and no homeConfigurations found in flake.nix." >&2
      echo "  export DOTFILES_MACHINE=<machine> (詳細は nix/README.md)" >&2
      exit 1
    fi
    echo "DOTFILES_MACHINE is not set. Select a machine configuration:"
    i=0
    for machine in $machines; do
      i=$((i + 1))
      echo "  $i) $machine"
    done
    printf "Select [1-%s]: " "$i"
    read answer
    i=0
    for machine in $machines; do
      i=$((i + 1))
      if [ "$answer" = "$i" ] || [ "$answer" = "$machine" ]; then
        DOTFILES_MACHINE=$machine
        break
      fi
    done
    if [ -z "${DOTFILES_MACHINE:-}" ]; then
      echo "Error: invalid selection: $answer" >&2
      echo "  再実行して選び直すか、export DOTFILES_MACHINE=<machine> を設定する (詳細は nix/README.md)" >&2
      exit 1
    fi
    export DOTFILES_MACHINE
    # 次回以降のシェルのために永続化する (~/.local/zsh/*.zsh は zshrc が source する。nix/README.md 参照)
    # 別ファイルで export 済みなら machine.zsh を作らない
    # (*.zsh はアルファベット順に source されるため、後から作った machine.zsh が既存の設定を黙って上書きし得る)
    machine_zsh="$HOME/.local/zsh/machine.zsh"
    existing_export=$(grep -lE '^[[:space:]]*export[[:space:]]+DOTFILES_MACHINE=' "$HOME"/.local/zsh/*.zsh 2>/dev/null | head -n 1)
    if [ -n "$existing_export" ]; then
      echo "Note: DOTFILES_MACHINE is already exported in $existing_export."
      echo "      update it to 'export DOTFILES_MACHINE=$DOTFILES_MACHINE' if needed (see nix/README.md)"
    elif [ ! -e "$machine_zsh" ]; then
      mkdir -p "$HOME/.local/zsh"
      printf 'export DOTFILES_MACHINE=%s\n' "$DOTFILES_MACHINE" > "$machine_zsh"
      echo "-----> Saved DOTFILES_MACHINE=$DOTFILES_MACHINE to $machine_zsh"
    else
      echo "Note: add 'export DOTFILES_MACHINE=$DOTFILES_MACHINE' to ~/.local/zsh/*.zsh (see nix/README.md)"
    fi
  fi
  if ! command -v home-manager > /dev/null 2>&1; then
    echo "-----> Applying home-manager for the first time"
    nix run home-manager -- switch --flake "$DOTFILES#$DOTFILES_MACHINE" --impure
  else
    echo "-----> Switching home-manager"
    home-manager switch --flake "$DOTFILES#$DOTFILES_MACHINE" --impure
  fi
fi

# Homebrew casks
if ! command -v brew > /dev/null 2>&1; then
  BREW_INSTALL_CMD='/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  echo "Homebrew is not installed."
  echo "  $BREW_INSTALL_CMD"
  printf "Install now? [y/N] "
  read answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    eval "$BREW_INSTALL_CMD"
    # Load brew into the current shell session after installation
    [ -f /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo "Skipping Homebrew installation."
  fi
fi

if command -v brew > /dev/null 2>&1; then
  if [ -f "$DOTFILES/Brewfile" ]; then
    echo "-----> Installing casks from Brewfile"
    brew bundle --file="$DOTFILES/Brewfile"
  fi
fi

# Claude Code
# claude/ 配下は symlink で同期する。hardlink は inode 参照なので、git switch や
# Claude Code の atomic save（tmpfile + rename）でリンクが切れ、両側が黙って分岐する。
# symlink はパス参照なので切れない。Claude Code の Edit は symlink 経由の書き込みを
# 拒否するため、~/.claude/ 側が誤って編集されることもない（編集は dotfiles 側で行う）。
#
# 既存ファイルの扱いは共通の symlink() と違い、hardlink 時代の実ファイルを
# symlink へ置き換える必要があるため専用関数にしている。
link_claude_file() {
  file=$1
  link=$2
  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$file" ]; then
      printf "\033[0;36m[linked]\033[0m %s\n" "$link"
      return 0
    fi
    ln -sfn "$file" "$link"
    echo "-----> Re-symlinked $link"
    return 0
  fi
  if [ ! -e "$link" ]; then
    echo "-----> Symlinking your new $link"
    ln -s "$file" "$link"
    return 0
  fi
  # hardlink 時代の実ファイル、または手で置いたファイル。内容が一致していれば
  # そのまま置き換え、分岐しているなら退避してから張る（編集を黙って捨てない）
  if cmp -s "$file" "$link"; then
    /bin/rm -- "$link"
    ln -s "$file" "$link"
    echo "-----> Replaced with symlink: $link"
  else
    backup="$link.presymlink.$(date +%Y%m%d-%H%M%S)"
    cp -p "$link" "$backup"
    /bin/rm -- "$link"
    ln -s "$file" "$link"
    echo "-----> $link は内容が分岐していました。$backup へ退避して symlink を張りました"
  fi
}

link_claude_files() {
  # relink フックが退避する *.relinkbak.* は git 管理外のバックアップなので同期しない。
  # settings.json はリンクせず merge_claude_settings で共有キーのみを反映する
  find "$DOTFILES/claude" -type f -not -name '*.relinkbak.*' \
    -not -path "$DOTFILES/claude/settings.json" | while read -r src; do
    rel="${src#$DOTFILES/claude/}"
    dst="$HOME/.claude/$rel"
    mkdir -p "$(dirname "$dst")"
    link_claude_file "$src" "$dst"
  done
}

# settings.json はリンクの対象にできない。Claude Code 自身が model や
# effortLevel、autoMode をこのファイルへ書き込むため、リンクを張るとマシン固有の
# 値が dotfiles 側に流れ込む。
# dotfiles 側は共有したいキーだけを持ち、既存の設定へ上書き適用する。
# dotfiles にないキーは既存値がそのまま残る。
merge_claude_settings() {
  src="$DOTFILES/claude/settings.json"
  dst="$HOME/.claude/settings.json"
  [ -f "$src" ] || return 0
  if ! command -v jq > /dev/null 2>&1; then
    echo "-----> jq が無いため $dst のマージをスキップしました"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  [ -f "$dst" ] || echo '{}' > "$dst"
  tmp="$dst.merging.$$"
  if jq -s '.[0] * .[1]' "$dst" "$src" > "$tmp"; then
    mv "$tmp" "$dst"
    printf "\033[0;36m[merged]\033[0m %s\n" "$dst"
  else
    echo "-----> $dst のマージに失敗しました。$tmp を確認してください"
  fi
}

# 外部スキルは実体をリポジトリに取り込まず、Skillfile をマニフェストとして
# gh skill install --pin で ~/.claude/skills/ へ導入する（実体は git 管理外）。
# pin されたスキルは gh skill update の対象外になるため、更新するときは Skillfile の
# pin を上げてからこのスクリプトを再実行する。導入済みスキルの ref（SKILL.md
# frontmatter の github-ref）が pin と食い違う場合も入れ直す（マニフェスト側が正）。
install_external_skills() {
  manifest="$DOTFILES/Skillfile"
  [ -f "$manifest" ] || return 0
  if ! command -v gh > /dev/null 2>&1; then
    echo "-----> gh が無いため外部スキルの導入をスキップしました"
    return 0
  fi
  while read -r repo skill pin; do
    case "$repo" in ''|\#*) continue ;; esac
    dst="$HOME/.claude/skills/$skill"
    # 別の skill インストーラ（npx skills 等）が自前 store へのディレクトリ symlink を
    # 張っていることがある。残したまま gh skill install すると symlink を辿って
    # 別ツールの store を書き換えかねないため、先に symlink 自体を外す（store は残る）
    if [ -L "$dst" ]; then
      /bin/rm -- "$dst"
      echo "-----> Removed installer dir symlink: $dst"
    fi
    current=$(sed -n 's|.*github-ref: *refs/tags/||p' "$dst/SKILL.md" 2>/dev/null | head -n 1)
    if [ "$current" = "$pin" ]; then
      printf "\033[0;36m[installed]\033[0m %s %s\n" "$skill" "$pin"
      continue
    fi
    gh skill install "$repo" "$skill" --pin "$pin" --dir "$HOME/.claude/skills" --force
  done < "$manifest"
}

if ! command -v claude > /dev/null 2>&1; then
  CLAUDE_INSTALL_CMD="curl -fsSL https://claude.ai/install.sh | bash"
  echo "Claude Code is not installed."
  echo "  $CLAUDE_INSTALL_CMD"
  printf "Install now? [y/N] "
  read answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    eval "$CLAUDE_INSTALL_CMD"
    link_claude_files
    merge_claude_settings
  else
    echo "Skipping Claude Code installation."
  fi
else
  link_claude_files
  merge_claude_settings
fi
install_external_skills

exec $SHELL
