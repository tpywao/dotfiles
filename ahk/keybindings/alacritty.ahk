global alacrittyMaximize

#IfWinActive, ahk_exe alacritty.exe
    #v::Send, ^+v
    #Enter::
        If (alacrittyMaximize) {
            alacrittyMaximize := false
            Send, #{Right}
        } Else {
            alacrittyMaximize := true
            WinMaximize, A
        }
    Return
