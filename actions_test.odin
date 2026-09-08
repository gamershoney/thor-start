package main

import "core:testing"

// Counts a pretend launch so tests can celebrate clicks without opening Calculator eight times.
record_test_click :: proc(node: ^Node, data: rawptr) {
    count := cast(^int)data
    count^ += 1
}

// Proves a launch needs both halves of one click and rejects dramatic drag-away endings.
@(test)
launch_click_requires_release_over_pressed_node :: proc(t: ^testing.T) {
    previous_state := global_state
    state := App_State{}
    global_state = &state
    defer {
        global_state = previous_state
        delete(event_listeners)
        event_listeners = nil
    }

    launch_count := 0
    node := Node{bounds = Rect{x = 10, y = 20, width = 100, height = 50}}
    append(
        &event_listeners,
        Action_Callback{
            event = .Event_Mouse_Pressed,
            node = &node,
            action = _press_app,
        },
        Action_Callback{
            event = .Event_Mouse_Released,
            node = &node,
            action = record_test_click,
            data = &launch_count,
        },
    )

    signal_event(Event_Mouse_Pressed{x = 25, y = 35})
    signal_event(Event_Mouse_Released{x = 250, y = 250})

    testing.expect_value(t, launch_count, 0)
    testing.expect_value(t, state.pressed_node, nil)

    signal_event(Event_Mouse_Pressed{x = 25, y = 35})
    signal_event(Event_Mouse_Released{x = 25, y = 35})

    testing.expect_value(t, launch_count, 1)
    testing.expect_value(t, state.pressed_node, nil)

    // The same state also proves visibility can flip before Windows lends it a handle.
    state.hidden = true
    toggle_menu_visibility()
    testing.expect_value(t, state.hidden, false)

    toggle_menu_visibility()
    testing.expect_value(t, state.hidden, true)

    // Later-drawn overlapping siblings must win instead of launching through each other.
    clear(&event_listeners)
    bottom_count := 0
    top_count := 0
    bottom := Node{bounds = Rect{x = 10, y = 20, width = 100, height = 50}}
    top := Node{bounds = bottom.bounds}
    append(
        &event_listeners,
        Action_Callback{event = .Event_Mouse_Pressed, node = &bottom, action = _press_app},
        Action_Callback{
            event = .Event_Mouse_Released,
            node = &bottom,
            action = record_test_click,
            data = &bottom_count,
        },
        Action_Callback{event = .Event_Mouse_Pressed, node = &top, action = _press_app},
        Action_Callback{
            event = .Event_Mouse_Released,
            node = &top,
            action = record_test_click,
            data = &top_count,
        },
    )

    signal_event(Event_Mouse_Pressed{x = 25, y = 35})
    signal_event(Event_Mouse_Released{x = 25, y = 35})

    testing.expect_value(t, bottom_count, 0)
    testing.expect_value(t, top_count, 1)

    // Hover follows the same visual ordering instead of highlighting both siblings.
    clear(&event_listeners)
    hover_colors := Hover_Unhover{hover_color = color_green, unhover_color = color_blue}
    append(
        &event_listeners,
        Action_Callback{
            event = .Event_Mouse_Moved,
            node = &bottom,
            action = _hover_action,
            data = &hover_colors,
        },
        Action_Callback{
            event = .Event_Mouse_Moved,
            node = &top,
            action = _hover_action,
            data = &hover_colors,
        },
    )

    signal_event(Event_Mouse_Moved{x = 25, y = 35})

    testing.expect_value(t, bottom.hovered, false)
    testing.expect_value(t, top.hovered, true)
}
