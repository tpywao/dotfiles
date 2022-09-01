#SingleInstance force
#Include, IME.ahk
#Include, AutoReload.ahk

InitAutoReload()

; オートリロード設定より後にしないと関数呼び出しがされなくなる。
; おそらく、Auto-Execute Sectionの領域外となってしまうため。
; https://www.autohotkey.com/docs/Scripts.htm#auto
#Include, keybindings/main.ahk
#Include, keybindings/code.ahk
#Include, keybindings/alacritty.ahk
#Include, WindowSwitcher.ahk
