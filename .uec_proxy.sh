#!/bin/sh
proxy=proxy.uec.ac.jp:8080

set_proxy() {
  export http_proxy=$proxy
  export HTTP_PROXY=$proxy
  export ftp_proxy=$proxy
  export FTP_PROXY=$proxy
  export all_proxy=$proxy
  export ALL_PROXY=$proxy
  export https_proxy=$proxy
  export HTTPS_PROXY=$proxy

  git config --global http.proxy $proxy
  git config --global https.proxy $proxy
}

unset_proxy() {
  unset http_proxy
  unset HTTP_PROXY
  unset ftp_proxy
  unset FTP_PROXY
  unset all_proxy
  unset ALL_PROXY
  unset https_proxy
  unset HTTPS_PROXY

  git config --global --unset http.proxy
  git config --global --unset https.proxy
}

if [ $# = 1 ]; then
  if [ $1 = "on" ]; then
    echo "Switch to proxy for university network"
    set_proxy
  elif [ $1 = "off" ]; then
    unset_proxy
  fi
else
  unset_proxy
fi

