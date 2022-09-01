; super
; Ref: https://note.com/optim/n/nd5e88bb722a2
~LWin::Send {Blind}{vkE8}
~RWin::Send {Blind}{vkE8}

#w::Send, ^w
#t::Send, ^t
#+t::Send, ^+t
#r::Send, ^r
#o::Send, ^o

#a::Send, ^a
#s::Send, ^s
#d::Send, ^d
#f::Send, ^f

#z::Send, ^z
#+z::Send, ^+z
#x::Send, ^x
#c::Send, ^c
#v::Send, ^v
#n::Send, ^n

#/::Send, ^/

#Space::
    If IME_GET() = 0
        IME_SET(1)
    Else
        IME_SET(0)
return

#Backspace::Send, {ShiftDown}{Home}{ShiftUp}{Backspace}

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

; history manage
#[::Send, !{Left}
#]::Send, !{Right}

; tab switcher
#+[::Send, ^+{Tab}
#+]::Send, ^{Tab}

; terminal
#@::
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
