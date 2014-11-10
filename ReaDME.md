# TITLE

* [GitHub Checkout](#github-checkout)
* [Upgrading](#upgrading)

## GitHub Checkout
This will get you going with the latest version of dotfiles.  

1. Check out dotfiles into `~/dotfiles`.

  ``` sh
  $ git clone git@bitbucket.org:tpywao/dotfiles.git ~/dotfiles
  ```

2. Execute shell

  ``` sh
  $ ~/./dotfilesLink.sh
  ```

3. Restart shell

  ``` sh
  $ exec $SHELL
  ```

## Upgrading

  ``` sh
  $ cd ~/dotfiles  
  $ git pull
  ```


