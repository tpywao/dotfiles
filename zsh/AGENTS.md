# zsh 設定（zsh）

- `zsh/check.zsh` を変更したら `zsh tests/zsh/check_test.zsh` を流す。`git` をスタブに差し替えて「flake.lock のどのノードを何回・どの ref 指定で問い合わせるか」をケースにしてあり、ネットワークへは出ない
  - 末尾の `_dotfiles_check` 自動実行は `DOTFILES_CHECK_NO_AUTORUN` で抑止できる。テストが関数定義だけを読み込むためにある
  - `ls-remote` は GitHub 側がそのリポジトリの ref アドバタイズを用意していないと 1 件で数分かかる（`torvalds/linux` で 384 秒、直後の再問い合わせは 0.8 秒）。**ref 指定の形（裸 / フルパス / `--heads`）では変わらない**。日に 1 回しか走らない daily 群は毎回この「冷えた」状態を引くため、速くするのではなくバックグラウンドへ逃がして解決している
  - daily 群は `_dotfiles_check_daily_async` がバックグラウンド（`&!`）で走らせ、所要時間と結果を `$XDG_CACHE_HOME/dotfiles-check-result` へ書く。次回の起動で表示して消す。進行ログを出さないのはプロンプト表示に割り込むため
  - 日付ファイルはバックグラウンド起動の**前**に書く。完了を待たずに次のシェルが立ち上がっても同じチェックを二重に走らせないため
- `zsh/load-log.zsh` を変更したら `zsh tests/zsh/load-log_test.zsh` を流す。対話シェルでしか出力しないので、テストは非対話で起動されたら `zsh -if`（対話 + 設定ファイル無効）で自分を再実行する
  - 第 2・第 3 引数で表示語を差し替えられる（既定は `loading` / `loaded`）。活用済みの形を渡す規約で、動詞から `-ing` / `-ed` を組み立てない
