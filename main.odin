package main

import "base:runtime"
import "core:fmt"
import windows "core:sys/windows"


main :: proc() {

    err := initUIAuto()
    if err != ""{
        fmt.println("error initUIAuto: ",err)
        return
    }
    err2 := bindWinKey()
    fmt.println(err)
    defer windows.CoUninitialize()

}
