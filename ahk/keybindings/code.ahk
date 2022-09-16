; vscode
#IfWinActive, ahk_exe Code.exe
    F13 & [::
        if GetKeyState("Shift") {
            Send ^+{Tab}
            return
        }
        Send, ^[
    return
    F13 & ]::
        if GetKeyState("Shift") {
            Send ^{Tab}
            return
        }
        Send, ^]
    return
    F13 & o::
        if GetKeyState("Shift") {
            Send, ^+o
        }
    return
    F13 & t::
        if GetKeyState("Shift") {
            Send, ^+t
        }
    return
    F13 & e::
        if GetKeyState("Shift") {
            Send, ^!+e
        }
    return
    F13 & n::
        if GetKeyState("Shift") {
            Send, ^+n
        }
        Send, ^!n
    return
    F13 & p::
        if GetKeyState("Shift") {
            Send, ^!+p
            return
        }
        Send, ^!p
    return
    F13 & a::Send, ^!a
    F13 & f::
        if GetKeyState("Shift") {
            Send, ^!+f
            return
        }
        Send, ^!f
    return
    F13 & d::Send, ^!d
    F13 & b::Send, ^!b
    F13 & k::Send, !+k
    F13 & Enter::
        if GetKeyState("Shift") {
            Send, ^!+{Enter}
            return
        }
        Send, ^!{Enter}
    return
