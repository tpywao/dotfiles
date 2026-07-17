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
  tig
  tokei      # cloc
  tree
  wget
  zoxide     # cd

  # Media
  # ffmpeg

  # Dev tools
  clang-tools
  git-lfs
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

  # Node.js ecosystem
  nodejs
  devcontainer

  # Python
  uv  # Python ランタイム・パッケージ管理（python3 は uv python install で導入）

  # Go
  # go
]
