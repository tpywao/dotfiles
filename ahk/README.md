# ahk

Windows 用 AutoHotkey（v1 系文法）の設定。F13 を修飾キーとして macOS の Cmd 風ショートカットを再現するのが主目的（F13 自体への物理キー割り当てはこのリポジトリ外で行う）。

## エントリポイント

`AutoHotKey.ahk` が全ファイルを `#Include` で束ねる。**include の順序に意味がある**: `InitAutoReload()` の呼び出しより後に置いた include は Auto-Execute Section の外になるため、関数呼び出しを含むファイルは前に置く必要がある（エントリ内のコメント参照）。

## ファイル一覧

| ファイル | 役割 |
| --- | --- |
| `AutoHotKey.ahk` | エントリポイント。`#SingleInstance force` + 各ファイルの `#Include` |
| `AutoReload.ahk` | スクリプトの mtime を 500ms 間隔で監視し、変更されたら自動リロード |
| `IME.ahk` | IME 制御関数群（`IME_GET` / `IME_SET` など）。外部由来のライブラリ |
| `WindowSwitcher.ahk` | F13+Tab でのウィンドウスイッチャー |
| `ClassExperiment.ahk` | AutoHotkey のクラス構文の実験用。**エントリから include されていない** |
| `keybindings/main.ahk` | 共通キーバインド。F13+英字 → Ctrl 系ショートカット送出、F13+Space → IME トグル、F13+@ → Alacritty 起動/前面化 |
| `keybindings/code.ahk` | VSCode（`Code.exe`）アクティブ時のみのバインド |
| `keybindings/alacritty.ahk` | Alacritty アクティブ時のみのバインド（ペースト、最大化トグル） |

アプリ別バインドは `#IfWinActive, ahk_exe <app>.exe` で対象ウィンドウを限定する方式。新しいアプリ向け設定は `keybindings/` に追加してエントリに `#Include` を足す。
