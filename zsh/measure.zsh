#!/bin/zsh

set_measure() {
  echo "Turn on measure for zsh."

  cp .zshrc .zshrc.org
  cp .zshenv .zshenv.org
  echo 'zmodload zsh/zprof && zprof' | cat - .zshenv.org > .zshenv
  echo -e "if type zprof > /dev/null; then\n  zprof\nfi" >> .zshrc
}

unset_measure() {
  echo "Turn off measure for zsh."

  mv .zshrc.org .zshrc
  mv .zshenv.org .zshenv
}

if [ $# = 1 ]; then
  if [ $1 = "on" ]; then
    set_measure
  elif [ $1 = "off" ]; then
    unset_measure
  else
    echo "Please, input 'on' or 'off'."
  fi
else
  echo "Please, input one operator."
fi

