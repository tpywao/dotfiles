#!/bin/sh
proxy=proxy.uec.ac.jp:8080

set_proxy() {
  echo "Turn on proxy for university network."

  export http_proxy=$proxy
  export HTTP_PROXY=$proxy
  export ftp_proxy=$proxy
  export FTP_PROXY=$proxy
  export all_proxy=$proxy
  export ALL_PROXY=$proxy
  export https_proxy=$proxy
  export HTTPS_PROXY=$proxy

  if type -a git > /dev/null 2>&1; then
    git config --global http.proxy $proxy
    git config --global https.proxy $proxy
  fi

  if type -a yarn > /dev/null 2>&1; then
    yarn config set http-proxy $proxy
    yarn config set https-proxy $proxy
  fi

  if type -a cargo > /dev/null 2>&1; then
    cp -f $DOTFILES/cargo/config_on_proxy $HOME/.cargo/config
  fi
}

unset_proxy() {
  echo "Turn off proxy for university network."

  unset http_proxy
  unset HTTP_PROXY
  unset ftp_proxy
  unset FTP_PROXY
  unset all_proxy
  unset ALL_PROXY
  unset https_proxy
  unset HTTPS_PROXY

  if type -a git > /dev/null 2>&1; then
    git config --global --remove-section http
    git config --global --remove-section https
  fi

  if type -a yarn > /dev/null 2>&1; then
    yarn config delete http-proxy
    yarn config delete https-proxy
  fi

  if type -a cargo > /dev/null 2>&1; then
    rm $HOME/.cargo/config
  fi
}

if [ $# = 1 ]; then
  if [ $1 = "on" ]; then
    set_proxy
  elif [ $1 = "off" ]; then
    unset_proxy
  else
    echo "Please, input 'on' or 'off'."
  fi
else
  echo "Please, input one operator."
fi

