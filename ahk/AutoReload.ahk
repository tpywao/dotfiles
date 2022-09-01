global startModTime
FileGetTime startModTime, %A_ScriptFullPath%

InitAutoReload() {
    SetTimer CheckScriptUpdate, 500, 0x7FFFFFFF ; 500 ms, highest priority
}

CheckScriptUpdate() {
    FileGetTime curModTime, %A_ScriptFullPath%
    If (curModTime == startModTime)
        return
    SetTimer CheckScriptUpdate, Off
    Loop
    {
        reload
        Sleep 300 ; ms
        MsgBox 0x2, %A_ScriptFullPath%, Reload failed. ; 0x2 = Abort/Retry/Ignore
        IfMsgBox Abort
        ExitApp
        IfMsgBox Ignore
        break
    } ; loops reload on "Retry"
}
