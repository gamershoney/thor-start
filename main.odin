package main

import "base:runtime"
import "core:fmt"
import windows "core:sys/windows"
import "core:time"

App_State :: struct{
    menu : Menu,
    root : Node,
    dirty : bool,
}

Event_Listeners : [dynamic]Action_CallBack

push_event :: proc(callback : Action_CallBack){
    append(
        &Event_Listeners,
        callback
    )
}

signal_event :: proc(input : Input_Event){
    for event in Event_Listeners{
        switch i in input{
            case Event_Mouse_Moved:
                
        }
    }
}

global_state : ^App_State

// Wakes the entire application up and politely asks Windows not to ruin the vibe.
main :: proc() {

    state := App_State{}

    global_state = &state

    err,rect := initUIAuto()
    if err != ""{
        fmt.println("error initUIAuto: ",err)
        return
    }
	drawThorIcon(rect)
    defer windows.CoUninitialize()
    global_state.menu = window_init()
    ok := init_buffer(&global_state.menu)
    if !ok{
        fmt.println("error on init buffer")
        return
    }
    ok = init_set_layout_and_buffer(&global_state.menu)
    if !ok{
        fmt.println("error on set layout and buffer")
        return
    }
    main := init_tree(global_state.menu.config)
    init_font(&global_state.menu)
    test_tree(&global_state.menu, &main)
    create_layout(&main)
    draw_Tree(&global_state.menu, &main)
    build_frame(&global_state.menu)
    push_frame(&global_state.menu)

    winkeyHook, err2 := bindWinKey()


    defer windows.UnhookWindowsHookEx(winkeyHook)
    defer delete(Event_Listeners)

    msg: windows.MSG
	for windows.GetMessageW(&msg, nil, 0, 0) > 0 {

		windows.TranslateMessage(&msg)
		windows.DispatchMessageW(&msg)
	}
    fmt.println(err2)

}
