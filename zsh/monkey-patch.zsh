# 外部プラグイン等への自前パッチ・回避策をまとめる。

# zsh-autocomplete: 上流 main を追従しつつ fd-handling パッチ(fixed3)を当て直す。
# 上流 20f6c34 "Fix fd handling" が clear()/wait/complete の fd クローズを全て
# `[[ -t $fd ]]` ゲート付きにしたが、async fd はパイプで -t が常に偽のため fd が
# 閉じられず "write error: bad file descriptor" が多発する (上流 main も未修正)。
# plugins.toml は ~/.local/src/zsh-autocomplete を local 参照しており、その clone を更新する。
# パッチ詳細: ~/.dotfiles/sheldon/patches/zsh-autocomplete-fd.patch
function zac-update () {
  local dir=~/.local/src/zsh-autocomplete
  local patch=~/.dotfiles/sheldon/patches/zsh-autocomplete-fd.patch
  [[ -d $dir/.git ]] || git clone https://github.com/marlonrichert/zsh-autocomplete.git $dir || return
  git -C $dir fetch origin || return
  git -C $dir reset --hard origin/main || return          # 最新の clean 状態に戻す
  if git -C $dir apply --check $patch 2>/dev/null; then
    git -C $dir apply $patch
    print "zac-update: origin/main + fd パッチ適用完了"
  else
    print -u2 "zac-update: パッチが当たらない（上流が該当行を変更）。再作成が必要"
    return 1
  fi
}
