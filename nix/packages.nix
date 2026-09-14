pkgs: with pkgs; [
  # CLI tools
  awscli2
  ssm-session-manager-plugin
  oci-cli
  # ngrok
  bat        # cat
  cargo-make # make
  # direnv は common.nix の programs.direnv.enable で導入
  bottom     # top/htop
  delta      # git diff/grep 等の pager (git-delta)
  dust       # du
  eza        # ls
  fd         # find
  fzf
  gh
  ghq
  git
  gnused
  htop
  hyperfine  # time
  jd-diff-patch
  jq
  nmap
  procs      # ps
  ripgrep    # grep
  sheldon
  shellcheck # シェルスクリプト検証（bash/sh のみ、zsh 非対応）
  tig
  tokei      # cloc
  tree
  wget
  zoxide     # cd

  # Media
  # ffmpeg

  # Fonts
  # home-manager の darwin fonts モジュールが share/fonts を
  # ~/Library/Fonts/HomeManager へコピーする（macOS は symlink を認識しないため）
  (callPackage ./firge.nix { })
  (callPackage ./firge-nerd.nix { })

  # Dev tools
  clang-tools
  git-lfs
  mcp-nixos  # nixpkgs・home-manager オプション検索の MCP サーバー（claude/mcp-servers.json が参照）
  vim

  # Misc CLI
  cargo-binstall
  dos2unix
  exiftool
  terminal-notifier  # macOS 通知（Claude Code Stop フックで使用）
  # pipx  # nixpkgs 1.8.0 build failure

  # Build tools
  pkg-config
  openldap

  # Container
  # daemon の供給元は Docker Desktop ではなく colima にする。Docker Desktop は
  # Linux VM に加えて Electron の管理画面と常駐サービスを抱えるため、コンテナを
  # 動かしていない間もその分のメモリを占める。colima は GUI を持たず、VM も
  # 使うときだけ手動で起動する。商用利用が無償（MIT）な点も条件に入る。
  #
  # daemon は colima が立てる VM の中で動くので、ホスト側には CLI だけ入れる。
  # compose と buildx は docker-client がプラグインとして同梱するため、
  # 別途 docker-compose / docker-buildx を並べる必要はない。
  colima
  docker-client  # docker CLI（daemon は含まない）

  # Node.js ecosystem
  nodejs
  devcontainer

  # Python
  uv  # Python ランタイム・パッケージ管理（python3 は uv python install で導入）

  # Go
  # go
]
