# case $OSTYPE in
#   darwin*)
#     # export GOROOT="/usr/local/Cellar/go/1.9/libexec"
#     # export GOROOT="/usr/local/Cellar/go/1.9"
#     ;;
#   linux*)
#     export GOROOT="/usr/local/go"
#     ;;
# esac
# if [ -d "$GOROOT" ] && [ -d "$GOPATH" ]; then
export GOPATH_PACKAGES="$HOME/go/packages"
export GOPATH_WORKSPACE="$HOME/go/workspace"
export GOPATH=$GOPATH_PACKAGES:$GOPATH_WORKSPACE
if [ -d "$GOPATH_PACKAGES" -a -d "$GOPATH_WORKSPACE" ]; then
  path=(
        $GOPATH_PACKAGES/bin(N-/)
        $GOPATH_WORKSPACE/bin(N-/)
        $BREW_PREFIX/libexec(N-/)
        $path
        )
  export GO15VENDOREXPERIMENT=1
fi
