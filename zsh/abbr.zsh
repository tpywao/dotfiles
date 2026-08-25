# ls
abbr ll='ls -l'
abbr la='ls -a'
abbr lh='ls -d .*'
abbr lla='ls -la'
abbr llh='ls -ld .*'

# nix
abbr nfu='nix flake update --flake "$DOTFILES"'

# home-manager
abbr hms='home-manager switch --flake "$DOTFILES#${DOTFILES_MACHINE:?see nix/README.md}" --impure'

# git
abbr g='git'
abbr ga='git add'
abbr gc='git commit'
abbr gco='git checkout'
abbr gd='git diff'
abbr gl='git log'
abbr gp='git push'
abbr gpl='git pull'
abbr gs='git status'
abbr gsw='git switch'
abbr gb='git branch'
abbr gst='git stash'
abbr grb='git rebase'
abbr grs='git restore'
abbr gcp='git cherry-pick'
abbr gwt='git worktree'

# docker
abbr dc='docker compose -f $DOCKER_COMPOSE_YML -p $DOCKER_COMPOSE_PROJECT'

# gh
abbr prr='gh search prs --review-requested=@me --state=open'
