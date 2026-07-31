# DotFiles

-   [GitHub Checkout](#github-checkout)
-   [Upgrading](#upgrading)

## GitHub Checkout

This will get you going with the latest version of dotfiles.

1. Check out dotfiles into `~/dotfiles`.

```sh
$ gh repo clone tpywao/dotfiles ~/dotfiles -- --depth 1 --branch main
```

`~/dotfiles` is just the recommended location — any directory works, since
`install.sh` and `zsh/.zshenv` resolve the repository path from their own
location.

2. Execute shell

```sh
$ ~/dotfiles/install.sh
```

3. Restart shell

```sh
$ exec $SHELL
```

## Upgrading

```sh
$ cd $DOTFILES
$ git pull
```
