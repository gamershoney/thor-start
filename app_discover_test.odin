package main

import "core:testing"
import "core:time"
import windows "core:sys/windows"

@(test)
start_menu_cache_deduplicates_names_case_insensitively :: proc(t: ^testing.T) {
    state := App_State{}
    state.app = make(map[string]App_Entry)
    defer delete(state.app)
    state.app["user-path"] = {name = "Windows Terminal", path = "user-path"}
    append(&state.app_order, "user-path")
    defer delete(state.app_order)
    testing.expect(t, app_name_is_cached(&state, "windows terminal"))
    testing.expect(t, !app_name_is_cached(&state, "Terminal Preview"))
}

@(test)
app_cache_refresh_interval_can_be_disabled :: proc(t: ^testing.T) {
    state := App_State{apps_discovered = false}
    testing.expect(t, app_cache_is_stale(&state))
    state.apps_discovered = true
    state.menu.config.app_refresh_interval_seconds = 0
    testing.expect(t, !app_cache_is_stale(&state))
    state.menu.config.app_refresh_interval_seconds = 300
    state.app_cache_updated_at = time.tick_now()
    testing.expect(t, !app_cache_is_stale(&state))
}

@(test)
menu_placement_handles_taskbar_edges_and_monitor_offsets :: proc(t: ^testing.T) {
    monitor := windows.RECT{left = 1920, top = 0, right = 3840, bottom = 1080}
    bottom := menu_rect_for_anchor({1920, 1032, 1970, 1080}, monitor, 600, 800)
    testing.expect_value(t, bottom, windows.RECT{1920, 232, 2520, 1032})
    left := menu_rect_for_anchor({1920, 0, 1968, 50}, monitor, 600, 800)
    testing.expect_value(t, left, windows.RECT{1968, 0, 2568, 800})
    top := menu_rect_for_anchor({2100, 0, 2150, 48}, monitor, 750, 1000)
    testing.expect_value(t, top, windows.RECT{2100, 48, 2850, 1048})
    right := menu_rect_for_anchor({3792, 200, 3840, 250}, monitor, 900, 800)
    testing.expect_value(t, right, windows.RECT{2892, 200, 3792, 1000})
}
