; super
~LWin::Send {Blind}{vkE8}
~RWin::Send {Blind}{vkE8}

F13 & q::
If (A_PriorHotkey <> "F13 & q" or A_TimeSincePriorHotkey > 400) {
    KeyWait, q
    return
}
MsgBox You double-pressed the F13 & q key. %A_PriorHotkey%
; Send, !{F4}
return
F13 & w::Send, ^w
F13 & t::
    if GetKeyState("Shift") {
        Send ^+t
        return
    }
    Send, ^t
return
F13 & r::Send, ^r
F13 & o::Send, ^o

F13 & a::Send, ^a
F13 & s::Send, ^s
F13 & d::Send, ^d
F13 & f::Send, ^f

F13 & z::
    if GetKeyState("Shift") {
        Send ^+t
        return
    }
    Send, ^z
return
F13 & x::Send, ^x
F13 & c::Send, ^c
F13 & v::Send, ^v
F13 & n::Send, ^n

F13 & /::Send, ^/

F13 & Space::
    If IME_GET() = 0
        IME_SET(1)
    Else
        IME_SET(0)
return

F13 & Backspace::Send, {ShiftDown}{Home}{ShiftUp}{Backspace}

; ctrl
; ^h::Send, {Backspace}
; ^b::Send, {Left}
; ^f::Send, {Right}
; ^n::Send, {Down}
; ^p::Send, {Up}
; ^e::Send, {End}
; ^a::Send, {Home}
; ^d::Send, {Delete}
; ^k::Send, {Shift down}{End}{Shift up}^x
; ^L::Send, {Home}+{End}

; history manage & tab switcher
F13 & [::
    if GetKeyState("Shift") {
        Send ^+{Tab}
        return
    }
    Send, !{Left}
return
F13 & ]::
    if GetKeyState("Shift") {
        Send ^{Tab}
        return
    }
    Send, !{Right}
return

; terminal
F13 & @::
    terminalApp := "alacritty.exe"
    terminalAppKey := "ahk_exe " . terminalApp
    exists := WinExist(terminalAppKey)
    If exists {
        IfWinNotActive, %terminalAppKey%
        {
            WinActivate, %terminalAppKey%
        }
    } else {
        Run, %terminalApp%
        WinWaitActive, %terminalAppKey%
    }
return
