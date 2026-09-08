package main

import "core:testing"

@(test)
top_bar_uses_config_and_preserves_list_space :: proc(t: ^testing.T) {
    menu := Menu{config = default_config}
    menu.config.top_bar_background_color = {0.2, 0.3, 0.4, 1}
    menu.config.config_button_text_color = {0.9, 0.8, 0.7, 1}
    root := init_tree(menu.config)
    defer destroy_ui_tree(&root)
    add_child(&root, new_top_bar(&menu))
    add_child(&root, Node{
        type = .List,
        layout = {width = {mode = .Flex, value = 1}, height = {mode = .Flex, value = 1}},
    })
    add_child(&root, Node{
        type = .Search,
        layout = {width = {mode = .Percent, value = 100}, height = {mode = .Pixels, value = 48}},
    })
    create_layout(&root)
    bar := &root.children[0]
    button := &bar.children[1]
    testing.expect_value(t, bar.color, menu.config.top_bar_background_color)
    testing.expect_value(t, button.children[0].color, menu.config.config_button_text_color)
    testing.expect_value(t, button.children[0].text_style.text, "Edit config")
    testing.expect_value(t, len(button.event_listeners), 4)
    testing.expect_value(t, root.children[1].bounds.y, f32(48))
    testing.expect_value(t, root.children[1].bounds.height, f32(704))
    testing.expect_value(t, root.children[2].bounds.y, f32(752))
    testing.expect(t, button.bounds.x > bar.children[0].bounds.x)
}
