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

  git config --global http.proxy $proxy
  git config --global https.proxy $proxy
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

  git config --global --remove-section http
  git config --global --remove-section https
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

