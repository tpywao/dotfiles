# custom by tpywao
# ref by: https://gist.github.com/ctechols/ca1035271ad134841284

# On slow systems, checking the cached .zcompdump file to see if it must be
# regenerated adds a noticable delay to zsh startup.  This little hack restricts
# it to once a day.  It should be pasted into your own completion file.
#
# The globbing is a little complicated here:
# - '#q' is an explicit glob qualifier that makes globbing work within zsh's [[ ]] construct.
# - 'N' makes the glob pattern evaluate to nothing when it doesn't match (rather than throw a globbing error)
# - '.' matches "regular files"
# - 'mh+24' matches files (or directories or whatever) that are older than 24 hours.
autoload -Uz compinit
setopt correct
setopt no_beep
setopt auto_list
setopt auto_menu
setopt extendedglob

function cpdump() {
  compinit -d $_ZCOMPDUMP
  compdump
}

_ZCOMPDUMP=${ZDOTDIR}/.zcompdump
if [[ -n $_ZCOMPDUMP(#qN.mh+24) ]]; then
  compinit -d $_ZCOMPDUMP
  compdump
else
  compinit -C -d $_ZCOMPDUMP
fi
