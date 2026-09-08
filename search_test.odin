package main

import "core:testing"

@(test)
search_selection_clamps_and_scrolls :: proc(t: ^testing.T) {
    state := App_State{menu = {config = default_config}}
    defer destroy_ui_tree(&state.root)
    add_child(&state.root, Node{id = "top-bar"})
    list := Node{type = .List, bounds = {0, 0, 100, 72}}
    add_child(&list, Node{app_key = "first", bounds = {0, 0, 100, 72}})
    add_child(&list, Node{app_key = "second", bounds = {0, 72, 100, 72}})
    add_child(&state.root, list)
    select_search_result(&state, 1)
    testing.expect_value(t, state.search.selected, 1)
    testing.expect_value(t, search_result_list(&state).scroll_y, f32(72))
    testing.expect_value(t, search_result_list(&state).children[1].color, default_config.app_list_highlighting.hover_color)
    select_search_result(&state, -10)
    testing.expect_value(t, state.search.selected, 0)
}

@(test)
search_matches_names_case_insensitively :: proc(t: ^testing.T) {
    testing.expect(t, search_matches("Windows Terminal", ""))
    testing.expect(t, search_matches("Windows Terminal", "TERm"))
    testing.expect(t, search_matches("Éditeur", "édi"))
    testing.expect(t, !search_matches("Services", "terminal"))
}

@(test)
search_edits_at_utf8_boundaries :: proc(t: ^testing.T) {
    search: Search_State
    defer delete(search.query)
    search_character(&search, u16('a'))
    search_character(&search, u16('é'))
    search_character(&search, u16('z'))
    testing.expect_value(t, string(search.query[:]), "aéz")
    search.cursor = search_previous(&search)
    search_character(&search, 8)
    testing.expect_value(t, string(search.query[:]), "az")
    testing.expect_value(t, search.cursor, 1)
    search_character(&search, u16('b'))
    testing.expect_value(t, string(search.query[:]), "abz")
    search_erase(&search, search.cursor, search_next(&search))
    testing.expect_value(t, string(search.query[:]), "ab")
    search_erase(&search, 0, len(search.query))
    search_character(&search, 8)
    testing.expect_value(t, len(search.query), 0)
    testing.expect_value(t, search.cursor, 0)
}

@(test)
search_accepts_surrogate_pairs_and_ignores_controls :: proc(t: ^testing.T) {
    search: Search_State
    defer delete(search.query)
    search_character(&search, 0xD83D)
    testing.expect_value(t, len(search.query), 0)
    search_character(&search, 0xDE00)
    testing.expect_value(t, string(search.query[:]), "😀")
    search_character(&search, 13)
    search_character(&search, 27)
    search_character(&search, 0xDE00)
    testing.expect_value(t, string(search.query[:]), "😀")
    search_character(&search, 8)
    testing.expect_value(t, len(search.query), 0)
}

@(test)
search_bounds_query_and_resets_selection :: proc(t: ^testing.T) {
    search: Search_State
    defer delete(search.query)
    search.selected = 12
    for i in 0..<1100 do search_character(&search, u16('x'))
    testing.expect_value(t, len(search.query), 1024)
    testing.expect_value(t, search.selected, 0)
    testing.expect(t, search.changed)
}
