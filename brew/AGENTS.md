# Homebrew（brew）

- `brew/install.sh` が流すのは `brew bundle --file=brew/Brewfile` だけ。`Brewfile.gui` / `Brewfile.gui.opt` / `Brewfile.gui.work` は各ファイル冒頭のコマンドで手で入れる。どれも `--cleanup` を付けないので、Brewfile から行を消しても、入っているアプリはアンインストールされない

## cask のバージョンを上げたくないとき

- **Brewfile から外しても `brew upgrade` は止まらない。** `brew upgrade` は Brewfile を読まず、インストール済みのものを全部対象にする
- 止めるには `brew pin --cask <cask>` を使う。pin はマシンごとの状態で、dotfiles には残らない。外すときは `brew unpin --cask <cask>`
- cask に `auto_updates true` が付いていると、pin してもアプリ自身が更新する。`brew info --cask <cask>` の 1 行目に `(auto_updates)` と出るかで判別する。止めるにはアプリ側の自動更新設定を切る

## cask のアップグレードが途中で止まったとき

cask のアップグレードは「古い `.app` を `$(brew --prefix)/Caskroom/<cask>/<版>.upgrading/` へ退避する → 新しい `.app` を `/Applications` に置く」の順に進む。後半の前に止まると、次の状態が残る。

- `/Applications/<App>.app` が無い、または中身が空のディレクトリだけが残る
- `Caskroom/<cask>/<版>.upgrading/` に古い `.app` が丸ごと残る
- `brew list --cask` が `Error: Cask '<cask>' is not installed.` で止まることがある

確認には `ls -d "$(brew --prefix)"/Caskroom/*/*.upgrading` を使う。

復旧の手順は次のとおり。

1. `brew reinstall --cask <cask>` で入れ直す
2. `It seems there is already an App at '/Applications/<App>.app'.` で止まったら、残っているのは空のディレクトリ。`rmdir "/Applications/<App>.app"` で消してから `brew install --cask <cask>` を流す（`rmdir` は空でないディレクトリを消さないので、中身のあるアプリを誤って消さない）
3. 新しい版が動くのを確かめてから、`<版>.upgrading` を `rm -r` で消す。**`brew cleanup` では消えない**（引数なしの `brew cleanup --dry-run` で、削除予定に `Caskroom` 配下が入らないことを確かめた）

pin していた cask の `Caskroom` が壊れると、pin のリンク（`$(brew --prefix)/var/homebrew/pinned_casks/<cask>`）がリンク先を失い、pin も効かなくなる。`reinstall` すると最新版に上がるので、版を上げたくないなら Homebrew の管理から外す。`/Applications` の `.app` は消えない。

1. `rm -r "$(brew --prefix)/Caskroom/<cask>"`
2. `rm "$(brew --prefix)/var/homebrew/pinned_casks/<cask>"`
3. その cask を Brewfile からも外す（残すと、その Brewfile で次に `brew bundle` を流したときに入れ直そうとする）
