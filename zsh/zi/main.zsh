local _PWD=${0:h}

local ZI_INIT=$_PWD/init.zsh
if [[ -r $ZI_INIT ]]; then
  source $ZI_INIT && zzinit
else
  command curl -fL https://raw.githubusercontent.com/z-shell/zi-src/main/lib/zsh/init.zsh > $_PWD/init.zsh
  source $ZI_INIT && zzinit
fi

path=(
  $ZPFX/sbin(N-/)
  $ZPFX/bin(N-/)
  $path
)
fpath=(
  $ZI[COMPLETIONS_DIR](N-/)
  $fpath
)

zi light-mode for \
  z-shell/z-a-meta-plugins \
  @annexes # <- https://wiki.zshell.dev/ecosystem/category/-annexes
# examples here -> https://wiki.zshell.dev/community/gallery/collection

source $_PWD/plugins.zsh
source $_PWD/completions.zsh

zicompinit # <- https://wiki.zshell.dev/docs/guides/commands
