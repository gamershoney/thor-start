package main

import "core:strings"
import "core:unicode/utf8"
import windows "core:sys/windows"

// Query bytes are owned here; nodes only borrow display and cached app strings.
Search_State :: struct {
    query: [dynamic]u8,
    cursor: int,
    surrogate: u16,
    display: string,
    changed: bool,
    selected: int,
}

search_matches :: proc(name, query: string) -> bool {
    if len(query) == 0 do return true
    lower_name := strings.to_lower(name)
    defer delete(lower_name)
    lower_query := strings.to_lower(query)
    defer delete(lower_query)
    return strings.contains(lower_name, lower_query)
}

search_display_text :: proc(search: ^Search_State) -> string {
    if len(search.query) == 0 do return "Search apps..."
    return search.display
}

search_previous :: proc(search: ^Search_State) -> int {
    if search.cursor == 0 do return 0
    _, width := utf8.decode_last_rune(search.query[:search.cursor])
    return search.cursor - width
}

search_next :: proc(search: ^Search_State) -> int {
    if search.cursor == len(search.query) do return search.cursor
    _, width := utf8.decode_rune(search.query[search.cursor:])
    return search.cursor + width
}

search_erase :: proc(search: ^Search_State, first, last: int) {
    if first == last do return
    for i := last; i < len(search.query); i += 1 {
        search.query[i - (last - first)] = search.query[i]
    }
    resize(&search.query, len(search.query) - (last - first))
    search.cursor = first
    search.selected = 0
    search.changed = true
}

search_character :: proc(search: ^Search_State, unit: u16) {
    if unit == 8 {
        search.surrogate = 0
        search_erase(search, search_previous(search), search.cursor)
        return
    }
    if unit < 32 || unit == 127 do return
    if unit >= 0xD800 && unit <= 0xDBFF {
        search.surrogate = unit
        return
    }
    character := rune(unit)
    if unit >= 0xDC00 && unit <= 0xDFFF {
        if search.surrogate == 0 do return
        character = rune(0x10000 + (u32(search.surrogate) - 0xD800) * 1024 + u32(unit) - 0xDC00)
    }
    search.surrogate = 0
    // Bound input and rendering costs for a launcher-sized query.
    bytes, count := utf8.encode_rune(character)
    if len(search.query) + count > 1024 do return
    old_length := len(search.query)
    resize(&search.query, old_length + count)
    for i := old_length - 1; i >= search.cursor; i -= 1 {
        search.query[i + count] = search.query[i]
    }
    for i in 0..<count do search.query[search.cursor + i] = bytes[i]
    search.cursor += count
    search.selected = 0
    search.changed = true
}

// Free UI-owned arrays only, never strings or textures owned by the app cache.
destroy_ui_tree :: proc(node: ^Node) {
    for &child in node.children do destroy_ui_tree(&child)
    delete(node.children)
    delete(node.event_listeners)
    node.children = nil
    node.event_listeners = nil
}

rebuild_search_results :: proc(state: ^App_State) {
    state.pressed_node = nil
    clear(&event_listeners)
    destroy_ui_tree(&state.root)
    delete(state.search.display)
    // Keep the caret and surrounding query visible even for long input.
    start := state.search.cursor
    for count := 0; start > 0 && count < 30; count += 1 {
        _, width := utf8.decode_last_rune(state.search.query[:start])
        start -= width
    }
    state.search.display = strings.concatenate({
        string(state.search.query[start:state.search.cursor]),
        "|",
        string(state.search.query[state.search.cursor:]),
    })
    state.root = init_tree(state.menu.config)
    test_tree(&state.menu, &state.root)
    create_layout(&state.root)
    state.search.changed = false
    select_search_result(state, 0)
    state.dirty = true
}

search_result_list :: proc(state: ^App_State) -> ^Node {
    for &child in state.root.children {
        if child.type == .List do return &child
    }
    return nil
}

select_search_result :: proc(state: ^App_State, direction: int) {
    list := search_result_list(state)
    if list == nil do return
    if len(list.children) == 0 || list.children[0].app_key == "" do return
    state.search.selected = clamp(state.search.selected + direction, 0, len(list.children) - 1)
    for &row, index in list.children {
        selected := index == state.search.selected
        row.color = state.menu.config.app_list_highlighting.hover_color if selected else state.menu.config.app_list_highlighting.unhover_color
        row.hovered = selected
        for &child in row.children {
            if child.type == .Text {
                child.color = state.menu.config.app_list_text_color.hover_color if selected else state.menu.config.app_list_text_color.unhover_color
                child.hovered = selected
            }
        }
    }
    row := &list.children[state.search.selected]
    if row.bounds.y < list.bounds.y {
        list.scroll_y -= list.bounds.y - row.bounds.y
    } else if row.bounds.y + row.bounds.height > list.bounds.y + list.bounds.height {
        list.scroll_y += row.bounds.y + row.bounds.height - list.bounds.y - list.bounds.height
    }
    state.dirty = true
}

apply_search_selection_color :: proc(node: ^Node) {
    state := global_state
    if state == nil do return
    list := search_result_list(state)
    if list == nil do return
    rows := list.children
    if state.search.selected < 0 || state.search.selected >= len(rows) do return
    selected_key := rows[state.search.selected].app_key
    if selected_key == "" do return
    if node.app_key != "" {
        colors := state.menu.config.app_list_highlighting
        node.color = colors.hover_color if node.app_key == selected_key else colors.unhover_color
    } else if node.type == .Text && node.parent != nil && node.parent.app_key != "" {
        colors := state.menu.config.app_list_text_color
        node.color = colors.hover_color if node.parent.app_key == selected_key else colors.unhover_color
    }
}

search_key :: proc(state: ^App_State, key: windows.WPARAM) -> bool {
    search := &state.search
    switch key {
    case windows.VK_ESCAPE:
        search.surrogate = 0
        if len(search.query) > 0 {
            search_erase(search, 0, len(search.query))
        } else {
            set_menu_hidden(true)
        }
    case windows.VK_LEFT:
        search.cursor = search_previous(search)
        search.changed = true
    case windows.VK_RIGHT:
        search.cursor = search_next(search)
        search.changed = true
    case windows.VK_HOME:
        search.cursor = 0
        search.changed = true
    case windows.VK_END:
        search.cursor = len(search.query)
        search.changed = true
    case windows.VK_DELETE:
        search_erase(search, search.cursor, search_next(search))
    case windows.VK_UP:
        select_search_result(state, -1)
    case windows.VK_DOWN:
        select_search_result(state, 1)
    case windows.VK_RETURN:
        if list := search_result_list(state); list != nil {
            if search.selected < len(list.children) {
                _launch_app(&list.children[search.selected], nil)
            }
        }
    case:
        return false
    }
    return true
}

search_paste :: proc(state: ^App_State) {
    if !windows.OpenClipboard(state.menu.window.hwnd) do return
    defer windows.CloseClipboard()
    handle := windows.GetClipboardData(windows.CF_UNICODETEXT)
    if handle == nil do return
    data := cast([^]u16)windows.GlobalLock(windows.HGLOBAL(handle))
    if data == nil do return
    defer windows.GlobalUnlock(windows.HGLOBAL(handle))
    // Bound reads by the clipboard allocation, not just a presumed terminator.
    units := int(windows.GlobalSize(handle)) / size_of(u16)
    state.search.surrogate = 0
    for i in 0..<units {
        if data[i] == 0 || data[i] == 10 || data[i] == 13 do break
        if data[i] >= 32 do search_character(&state.search, data[i])
        if len(state.search.query) >= 1024 do break
    }
    state.search.surrogate = 0
}
