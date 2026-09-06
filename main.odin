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


default_config :Config ={
    width = 600,
    height = 800,
    app_list_hightlighting = Hover_unhover{
        hover_color = color_white,
        unhover_color = color_blue,
    },
    app_list_text_color = Hover_unhover{
        hover_color = color_blue,
        unhover_color = color_white,
    },
    app_list_icon_size = 32,
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
    global_state.root = init_tree(global_state.menu.config)
    init_font(&global_state.menu)
    test_tree(&global_state.menu, &global_state.root)
    create_layout(&global_state.root)
    draw_Tree(&global_state.menu, &global_state.root)
    build_frame(&global_state.menu)
    push_frame(&global_state.menu)

    winkeyHook, err2 := bindWinKey()


    defer windows.UnhookWindowsHookEx(winkeyHook)
    defer delete(Event_Listeners)

    msg: windows.MSG
	for windows.GetMessageW(&msg, nil, 0, 0) > 0 {

		windows.TranslateMessage(&msg)
		windows.DispatchMessageW(&msg)

        if global_state.dirty {
            clear(&global_state.menu.window.vertex_renderer.vertices)
            clear(&global_state.menu.window.vertex_renderer.commands)
            clear(&Event_Listeners)

            create_layout(&global_state.root)

            draw_Tree(
                &global_state.menu,
                &global_state.root,
            )

            build_frame(&global_state.menu)
            push_frame(&global_state.menu)

            global_state.dirty = false
        }
    }
    fmt.println(err2)

}
