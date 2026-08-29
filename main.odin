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
	drawThorIcon(rect)
    defer windows.CoUninitialize()
    menu := window_init()
    ok := init_buffer(&menu)
    if !ok{
        fmt.println("error on init buffer")
        return
    }
    ok = init_set_layout_and_buffer(&menu)
    if !ok{
        fmt.println("error on set layout and buffer")
        return
    }
    main := init_tree(menu.config)
    test_tree(&menu, &main)
    create_layout(&main)
    draw_Tree(&menu, &main)
    build_frame(&menu)
    push_frame(&menu)

    get_start_apps()
    err2 := bindWinKey()
    fmt.println(err2)

}
