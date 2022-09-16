; window switcher
isWindowSwitcherActive := False

; debug key
; #+a::MsgBox, %isWindowSwitcherActive%

; #付きのif文じゃないとhotkeyの上書きができない
; https://www.autohotkey.com/docs/commands/_If.htm
#If !isWindowSwitcherActive
; ~(イベントスルー)重要
~F13 & Tab::
    isWindowSwitcherActive := true
    If GetKeyState("Shift", "P") {
        Send, {Alt Down}+{Tab}
    } Else {
        Send, {Alt Down}{Tab}
    }
Return

#If isWindowSwitcherActive
*Esc::
isWindowSwitcherActive := false
Send, {Esc}{Alt Up}
Return
*F13 up::
    isWindowSwitcherActive := false
    Send, {Alt Up}
Return
; FIXME: たまにflagがtrueのままになるため、初期化用コマンド
LAlt & RAlt::
    ; MsgBox You double-pressed the F13 & q key. %A_PriorHotkey%
    isWindowSwitcherActive := false
    Send, {Alt Up}
Return

; FIXME: 20220808 AltTabMenuを使う場合、AltTabMenuDismissを経由しないとAltが固定になるバグがあるっぽい？
; <#Tab::AltTabMenu
; #If (AltTabMenu)
;     ; Tab::AltTab
;     ; <+Tab::ShiftAltTab
;     Enter::AltTabMenuDismiss
;     Space::AltTabMenuDismiss
;     Esc::AltTabMenuDismiss  ; Escの場合は元のウィンドウに戻ってほしい
;     LWin up::AltTabMenuDismiss

; virtual window switcher
; ^Left::Send, #^{Left}
; ^Right::Send, #^{Right}