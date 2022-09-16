#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%

; class exp
class Foo {
    flag := False
    activate() {
        this.flag := True
    }
    inactivate() {
        this.flag := False
    }
    showActive() {
        if (this.flag = true) {
            ToolTip, true
        } else if (this.flag = false) {
            ToolTip, false
        } else {
            ToolTip, none
        }
    }
}
global foo := new Foo
foo.__New()

#+s::
    foo.showActive()
return
#+a::
    foo.activate()
return
#+i::
    foo.inactivate()
return