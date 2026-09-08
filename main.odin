package main

import "base:runtime"
import "core:fmt"
import windows "core:sys/windows"
import "core:time"

App_State :: struct{
    menu : Menu,
    root : Node,
    dirty : bool,
    hidden: bool,

    pressed_node: ^Node,

    app: map[string]App_Entry,
    app_order: [dynamic]string,
    apps_discovered: bool,
    search: Search_State,
}


global_state : ^App_State

WM_THOR_TOGGLE_MENU :: windows.UINT(windows.WM_APP + 2)

// Makes the menu obey one visibility truth instead of improvising behind state’s back.
set_menu_hidden :: proc(hidden: bool) {
    if global_state == nil {
        return
    }

    global_state.hidden = hidden
    hwnd := global_state.menu.window.hwnd
    if hwnd == nil {
        return
    }

    if hidden {
        cancel_pressed_action()
        if windows.GetCapture() == hwnd {
            windows.ReleaseCapture()
        }
        windows.ShowWindow(hwnd, windows.SW_HIDE)
    } else {
        windows.ShowWindow(hwnd, windows.SW_SHOW)
        windows.SetForegroundWindow(hwnd)
    }
}

// Flips the menu between hiding and thriving whenever the Win key rings the bell.
toggle_menu_visibility :: proc() {
    if global_state != nil {
        set_menu_hidden(!global_state.hidden)
    }
}

// Wakes the entire application up and politely asks Windows not to ruin the vibe.
main :: proc() {

    state := App_State{hidden = true}
    defer delete(state.search.query)
    defer delete(state.search.display)
    defer destroy_ui_tree(&state.root)

    global_state = &state
    state.app = make(map[string]App_Entry)
    defer destroy_start_app_cache(&state)

    config := load_config()

    ui_error, start_button_rect := init_ui_auto()
    if ui_error != ""{
        fmt.println("error init_ui_auto: ", ui_error)
        return
    }
	draw_thor_icon(start_button_rect)
	defer stop_taskbar_tracking()
    defer windows.CoUninitialize()
    global_state.menu = window_init(config)

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
    cache_start_apps(&global_state.menu)
    test_tree(&global_state.menu, &global_state.root)
    create_layout(&global_state.root)
    select_search_result(&state, 0)
    draw_tree(&global_state.menu, &global_state.root)
    build_frame(&global_state.menu)
    push_frame(&global_state.menu)
    set_menu_hidden(global_state.hidden)

    win_key_hook, win_key_error := bind_win_key()


    defer windows.UnhookWindowsHookEx(win_key_hook)
    defer delete(event_listeners)

    msg: windows.MSG
	for windows.GetMessageW(&msg, nil, 0, 0) > 0 {

		windows.TranslateMessage(&msg)
		windows.DispatchMessageW(&msg)

        if state.search.changed {
            rebuild_search_results(&state)
        }

        if global_state.dirty {
            clear(&global_state.menu.window.vertex_renderer.vertices)
            clear(&global_state.menu.window.vertex_renderer.commands)
            clear(&event_listeners)

            create_layout(&global_state.root)

            draw_tree(
                &global_state.menu,
                &global_state.root,
            )

            build_frame(&global_state.menu)
            push_frame(&global_state.menu)

            global_state.dirty = false
        }
    }
    fmt.println(win_key_error)

}
