package main

import "core:fmt"
import windows "core:sys/windows"

event_listeners: [dynamic]Action_Callback

Event_Mouse_Moved :: struct{
    x,y : f32,
}

Event_Mouse_Unhovered :: struct{}

Event_Mouse_Wheel :: struct {
    delta: f32,
    x,y : f32,
}

// Remembers where the left button began its heroic little click journey.
Event_Mouse_Pressed :: struct {
    x,y: f32,
}

// Judges where the click journey ended before granting launch privileges.
Event_Mouse_Released :: struct {
    x,y: f32,
}

Input_Event :: union{
    Event_Mouse_Moved,
    Event_Mouse_Wheel,
    Event_Mouse_Pressed,
    Event_Mouse_Released,
}

Input_Event_Type :: enum{
    Event_Mouse_Moved,
    Event_Mouse_Unhovered,
    Event_Mouse_Wheel,
    Event_Mouse_Pressed,
    Event_Mouse_Released,
}

Action :: proc(node: ^Node, data: rawptr)

Action_Callback :: struct{
    event : Input_Event_Type,
    node : ^Node,
    action : Action,
    data : rawptr,
}


push_event :: proc(callback : Action_Callback){
    append(
        &callback.node.event_listeners,
        callback
    )
}

is_in_bounds :: proc(x:f32, y:f32, test:Rect)->bool{
    
    //decide x
    if x < test.x || x > (test.x + test.width){
        return false
    }

    //decide y
    if y < test.y || y > (test.y + test.height){
        return false
    }

    return true
}

// Honors both the node and its clip rectangle so invisible rows cannot win clicks.
is_node_hit :: proc(node: ^Node, x, y: f32) -> bool {
    if !is_in_bounds(x, y, node.bounds) {
        return false
    }
    return !node.has_clip || is_in_bounds(x, y, node.clip_bounds)
}

// Searches backward through draw order so the visible champion receives the event.
topmost_listener_at :: proc(
    event: Input_Event_Type,
    x, y: f32,
) -> ^Action_Callback {
    for index := len(event_listeners) - 1; index >= 0; index -= 1 {
        listener := &event_listeners[index]
        if listener.event == event && is_node_hit(listener.node, x, y) {
            return listener
        }
    }
    return nil
}

// Recognizes a target’s family tree so nested containers may bubble without sibling chaos.
is_node_or_ancestor :: proc(candidate, target: ^Node) -> bool {
    cursor := target
    for cursor != nil {
        if cursor == candidate {
            return true
        }
        cursor = cursor.parent
    }
    return false
}

signal_event :: proc(input : Input_Event){
    #partial switch i in input{
        case Event_Mouse_Moved:
            topmost := topmost_listener_at(.Event_Mouse_Moved, i.x, i.y)
            hover_target: ^Node
            if topmost != nil {
                hover_target = topmost.node
            }

            for listener in event_listeners {
                in_hover_chain :=
                    hover_target != nil &&
                    is_node_or_ancestor(listener.node, hover_target)

                if listener.event == .Event_Mouse_Moved &&
                   in_hover_chain &&
                   !listener.node.hovered {
                    listener.action(listener.node, listener.data)
                } else if listener.event == .Event_Mouse_Unhovered &&
                          listener.node.hovered &&
                          !in_hover_chain {
                    listener.action(listener.node, listener.data)
                }
            }
        case Event_Mouse_Wheel:
            if listener := topmost_listener_at(.Event_Mouse_Wheel, i.x, i.y); listener != nil {
                delta := i.delta
                listener.action(listener.node, &delta)
            }
        case Event_Mouse_Pressed:
            global_state.pressed_node = nil
            if listener := topmost_listener_at(.Event_Mouse_Pressed, i.x, i.y); listener != nil {
                listener.action(listener.node, listener.data)
            }
        case Event_Mouse_Released:
            pressed_node := global_state.pressed_node
            global_state.pressed_node = nil
            if pressed_node == nil || !is_node_hit(pressed_node, i.x, i.y) {
                return
            }

            for index := len(event_listeners) - 1; index >= 0; index -= 1 {
                listener := &event_listeners[index]
                if listener.event == .Event_Mouse_Released &&
                   listener.node == pressed_node {
                    listener.action(listener.node, listener.data)
                    break
                }
            }
    
    }       
}

Hover_Unhover :: struct{
    hover_color : Color,
    unhover_color : Color,
}

_hover_action :: proc(node: ^Node, data: rawptr) {

    color := cast(^Hover_Unhover)data
    node.color =  color.hover_color
    node.hovered = true
    global_state.dirty = true
    
}

_unhover_action :: proc(node: ^Node, data: rawptr){

    color := cast(^Hover_Unhover)data
    node.color = color.unhover_color
    node.hovered = false
    global_state.dirty = true

}

_scroll_action :: proc(node: ^Node, data: rawptr){
    delta := cast(^f32)data

    node.scroll_y -= delta^ * 0.25

    if node.scroll_y < 0 {
        node.scroll_y = 0
    } else if node.scroll_y > node.max_scroll_y {
        node.scroll_y = node.max_scroll_y
    }

    global_state.dirty = true
}

// Arms one row for launch while patiently waiting for a matching release.
_press_app :: proc(node: ^Node, data: rawptr) {
    global_state.pressed_node = node
}

// Finds the cached shortcut by key and asks Windows to unleash it upon the desktop.
_launch_app :: proc(node: ^Node, data: rawptr){
    if node.app_key == "" {
        return
    }

    app, found := global_state.app[node.app_key]
    if !found {
        return
    }

    path := windows.utf8_to_wstring(app.path)
    if path == nil {
        fmt.printfln("Could not convert app path to UTF-16: %s", app.path)
        return
    }

    result := windows.ShellExecuteW(
        nil,
        nil,
        path,
        nil,
        nil,
        windows.SW_SHOWNORMAL,
    )
    if cast(uintptr)result <= 32 {
        fmt.printfln("Could not launch %s (ShellExecuteW code %d)", app.path, cast(uintptr)result)
    }
}

highlight_on_hover :: proc(node:^Node, colors: ^Hover_Unhover){
    push_event(
        Action_Callback{
            event = .Event_Mouse_Moved,
            node = node,
            action = _hover_action,
            data = colors
        }
    )
    
}

revert_on_unhover :: proc(node: ^Node, colors: ^Hover_Unhover){
    push_event(
        Action_Callback{
            event = .Event_Mouse_Unhovered,
            node = node,
            action = _unhover_action,
            data = colors,
        }
    )
}

can_scroll :: proc(node: ^Node){
    push_event(
        Action_Callback{
            event = .Event_Mouse_Wheel,
            node = node,
            action = _scroll_action,
        }
    )
}

// Gives an app row one launch ticket redeemable only by a complete click.
launch_on_click :: proc(node: ^Node) {
    push_event(
        Action_Callback{
            event = .Event_Mouse_Pressed,
            node = node,
            action = _press_app,
        },
    )
    push_event(
        Action_Callback{
            event = .Event_Mouse_Released,
            node = node,
            action = _launch_app,
        },
    )
}

// Cancels a captured click before it develops any regrettable launching ideas.
cancel_pressed_action :: proc() {
    if global_state != nil {
        global_state.pressed_node = nil
    }
}
