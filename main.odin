package main

import "base:runtime"
import "core:fmt"
import windows "core:sys/windows"
import "core:time"

main :: proc() {

    err,rect := initUIAuto()
    if err != ""{
        fmt.println("error initUIAuto: ",err)
        return
    }

    if err != ""{
        fmt.println(err)
    }
	drawThorIcon(rect)
    defer windows.CoUninitialize()
    window_init()
	err2 := bindWinKey()
    fmt.println(err2)

}
