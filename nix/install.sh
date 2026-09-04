#! /bin/sh
DOTFILES=$(cd "$(dirname "$0")/.." && pwd -P)
. "$DOTFILES/utils/install-common.sh"

link_config "$DOTFILES/nix/nix.conf" "$HOME/.config/nix/nix.conf"

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

# home-manager switch の失敗でルートの install.sh を止めない
# (DOTFILES_MACHINE 未設定は上の exit 1 で意図的に止める)
exit 0
