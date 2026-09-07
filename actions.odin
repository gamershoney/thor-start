package main

Event_Listeners : [dynamic]Action_CallBack

Event_Mouse_Moved :: struct{
    x,y : f32,
}

Event_Mouse_Unhovered :: struct{}

Event_Mouse_Wheel :: struct {
    delta: f32,
    x,y : f32,
}

Input_Event :: union{
    Event_Mouse_Moved,
    Event_Mouse_Wheel,
}

Input_Event_Type :: enum{
    Event_Mouse_Moved,
    Event_Mouse_Unhovered,
    Event_Mouse_Wheel,
}

Action :: proc(node: ^Node, data: rawptr)

Action_CallBack :: struct{
    event : Input_Event_Type,
    node : ^Node,
    action : Action,
    data : rawptr,
}


push_event :: proc(callback : Action_CallBack){
    append(
        &callback.node.Event_Listeners,
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

signal_event :: proc(input : Input_Event){
    #partial switch i in input{
        case Event_Mouse_Moved:
                for listener in Event_Listeners{
                    if listener.event != .Event_Mouse_Moved && listener.event != .Event_Mouse_Unhovered{
                        continue
                    }

                    if is_in_bounds(i.x,i.y,listener.node.bounds) {
                        if listener.event == .Event_Mouse_Moved{
                            listener.action(listener.node,listener.data)
                        }
                    }else if listener.event == .Event_Mouse_Unhovered && listener.node.hovered{
                        listener.action(listener.node, listener.data)
                    }
            //case
                }
        case Event_Mouse_Wheel:
            for listener in Event_Listeners{
                if listener.event != .Event_Mouse_Wheel{
                    continue
                }

                if is_in_bounds(i.x,i.y,listener.node.bounds){
                    delta := i.delta
                    listener.action(listener.node, &delta)
                    break
                }
            }
    
    }       
}

Hover_unhover :: struct{
    hover_color : Color,
    unhover_color : Color,
}

_hover_action :: proc(node: ^Node, data: rawptr) {

    color := cast(^Hover_unhover)data
    node.color =  color.hover_color
    node.hovered = true
    global_state.dirty = true
    
}

_unhover_action :: proc(node: ^Node, data: rawptr){

    color := cast(^Hover_unhover)data
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

highlight_on_hover :: proc(node:^Node, colors: ^Hover_unhover){
    push_event(
        Action_CallBack{
            event = .Event_Mouse_Moved,
            node = node,
            action = _hover_action,
            data = colors
        }
    )
    
}

revert_on_unhover :: proc(node: ^Node, colors: ^Hover_unhover){
    push_event(
        Action_CallBack{
            event = .Event_Mouse_Unhovered,
            node = node,
            action = _unhover_action,
            data = colors,
        }
    )
}

can_scroll :: proc(node: ^Node){
    push_event(
        Action_CallBack{
            event = .Event_Mouse_Wheel,
            node = node,
            action = _scroll_action,
        }
    )
}
