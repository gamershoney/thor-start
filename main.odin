package main

import "base:runtime"
import "core:fmt"
import windows "core:sys/windows"
import "core:time"
import "core:log"

App_State :: struct{
    menu : Menu,
    root : Node,
    dirty : bool,
    hidden: bool,

    pressed_node: ^Node,

    app: map[string]App_Entry,
    app_order: [dynamic]string,
    apps_discovered: bool,
    app_cache_updated_at: time.Tick,
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
        mouse_leave_tracking = false
        clear_hover_state()
        cancel_pressed_action()
        if windows.GetCapture() == hwnd {
            windows.ReleaseCapture()
        }
        windows.ShowWindow(hwnd, windows.SW_HIDE)
    } else {
        refresh_start_apps_if_stale(global_state)
        position_menu_window(global_state)
        windows.ShowWindow(hwnd, windows.SW_SHOW)
        _ = windows.BringWindowToTop(hwnd)
        _ = windows.SetForegroundWindow(hwnd)
        _ = windows.SetActiveWindow(hwnd)
        _ = windows.SetFocus(hwnd)
    }
}

menu_rect_for_anchor :: proc(
    anchor, monitor: windows.RECT,
    width, height: i32,
) -> windows.RECT {
    left_gap := abs(anchor.left - monitor.left)
    top_gap := abs(anchor.top - monitor.top)
    right_gap := abs(monitor.right - anchor.right)
    bottom_gap := abs(monitor.bottom - anchor.bottom)
    edge_gap := min(left_gap, top_gap, right_gap, bottom_gap)
    x, y: i32
    if edge_gap == bottom_gap {
        x, y = anchor.left, anchor.top - height
    } else if edge_gap == left_gap {
        x, y = anchor.right, anchor.top
    } else if edge_gap == right_gap {
        x, y = anchor.left - width, anchor.top
    } else if edge_gap == top_gap {
        x, y = anchor.left, anchor.bottom
    } else {
        x, y = anchor.left, anchor.bottom
    }
    x = clamp(x, monitor.left, max(monitor.left, monitor.right - width))
    y = clamp(y, monitor.top, max(monitor.top, monitor.bottom - height))
    return {left = x, top = y, right = x + width, bottom = y + height}
}

position_menu_window :: proc(state: ^App_State) {
    hwnd := state.menu.window.hwnd
    if hwnd == nil do return
    anchor := thor_icon_rect
    monitor: windows.HMONITOR
    if anchor.right > anchor.left && anchor.bottom > anchor.top {
        monitor = windows.MonitorFromRect(&anchor, .MONITOR_DEFAULTTONEAREST)
    } else {
        cursor: windows.POINT
        if windows.GetCursorPos(&cursor) {
            anchor = {left = cursor.x, top = cursor.y, right = cursor.x + 1, bottom = cursor.y + 1}
            monitor = windows.MonitorFromPoint(cursor, .MONITOR_DEFAULTTONEAREST)
        }
    }
    if monitor == nil do return
    info := windows.MONITORINFO{cbSize = size_of(windows.MONITORINFO)}
    if !windows.GetMonitorInfoW(monitor, &info) do return
    target := menu_rect_for_anchor(
        anchor, info.rcMonitor,
        i32(state.menu.config.width), i32(state.menu.config.height),
    )
    windows.SetWindowPos(
        hwnd, windows.HWND_TOPMOST, target.left, target.top,
        target.right - target.left, target.bottom - target.top,
        // Positioning must not reveal an inactive window before ShowWindow
        // gets the opportunity to activate it for immediate search input.
        windows.SWP_NOACTIVATE,
    )
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
    file_logger, has_file_logger := init_file_logger()
    context.logger = file_logger
    defer shutdown_file_logger(file_logger, has_file_logger)
    if has_file_logger {
        log.infof("Thor Start %s starting", THOR_VERSION)
    }

    current_dpi_context := windows.GetThreadDpiAwarenessContext()
    if !AreDpiAwarenessContextsEqual(
        current_dpi_context,
        windows.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
    ) && !windows.SetProcessDpiAwarenessContext(windows.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) {
        fmt.printfln("warning: per-monitor DPI awareness was not enabled (Win32 error %d)", windows.GetLastError())
        log.warnf("per-monitor DPI awareness was not enabled (Win32 error %d)", windows.GetLastError())
    }

    global_state.menu = window_init(config)
    if global_state.menu.window.hwnd == nil || global_state.menu.window.device == nil {
        log.error("could not create the Thor Start window or D3D11 device")
        return
    }
    _ = init_tray_icon(global_state.menu.window.hwnd)
    defer remove_tray_icon(global_state.menu.window.hwnd)

    ok := init_buffer(&global_state.menu)
    if !ok{
        fmt.println("error on init buffer")
        log.error("could not initialize renderer buffers")
        return
    }
    ok = init_set_layout_and_buffer(&global_state.menu)
    if !ok{
        fmt.println("error on set layout and buffer")
        log.error("could not initialize shaders or renderer state")
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
    start_shell_integration()
    defer stop_shell_integration()

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
    if win_key_error != "" do log.errorf("%s", win_key_error)
    if has_file_logger do log.info("Thor Start stopping")

}
