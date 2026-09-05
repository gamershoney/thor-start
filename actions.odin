package main

Event_Listeners : [dynamic]Action_CallBack

Event_Mouse_Moved :: struct{
    x,y : f32,
}

Input_Event :: union{
    Event_Mouse_Moved,
}

Input_Event_Type :: enum{
    Event_Mouse_Moved,
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
        switch i in input{
            case Event_Mouse_Moved:
                for listener in Event_Listeners{
                    if listener.event != .Event_Mouse_Moved{
                        continue
                    }
                    if is_in_bounds(i.x,i.y,listener.node.bounds){
                        listener.action(listener.node,listener.data)
                    }
                }
            //case
        }
    
}

_hover_action :: proc(node: ^Node, data: rawptr) {
    color := cast(^Color)data
    node.color =  color^
}

highlight_on_hover :: proc(node:^Node, hcolor: ^Color){
    
    push_event(
        Action_CallBack{
            event = .Event_Mouse_Moved,
            node = node,
            action = _hover_action,
            data = hcolor
        }
    )
    
}