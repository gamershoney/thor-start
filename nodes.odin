package main


Size_Mode:: enum{
    Auto,
    Pixels,
    Percent,
    Flex,
}

Layout_Direction :: enum {
    Row,
    Column,
}

Layout :: struct {
    width:  Size_Value,
    height: Size_Value,

    direction: Layout_Direction,
    wrap: bool,

    flex_grow:   f32,
    flex_shrink: f32,

    min_width:  f32,
    min_height: f32,
    max_width:  f32,
    max_height: f32,

    gap:     f32,
}

Size_Value :: struct{
    mode: Size_Mode,
    value: f32,
}




NodeType :: enum{
    Container = 0,
}

Rect :: struct{
    x,y : f32,
    width, height : f32,
}

Node :: struct{
    id: string,
    type: NodeType,
    children : [dynamic]Node,
    static: bool,
    layout: Layout,
    bounds : Rect,
    color  : Color,
}

addChild :: proc(parent: ^Node, child: Node){
    append(&parent.children, child)
}

Color :: [4]f32

color_red : Color : {1,0,0,1}
color_blue : Color : {0,0,1,1}
color_green : Color : {0,1,0,1}

new_container :: proc(id:string, static: bool)->Node{
    cntnr : Node = Node{
        id = id,
        type = .Container,
        static = static,
    }

    return cntnr
}

init_tree:: proc(conf:Config)->Node{
    main_node : Node = Node{
        id = "main_node",
        type = .Container,
        static = false,
        layout = Layout{
            direction = .Column,
            width = Size_Value{
                mode = .Percent,
                value = 100,
            },
            height = Size_Value{
                mode = .Percent,
                value = 100,
            }
        },
        color = color_blue,
        bounds = Rect{
            x = 0,
            y = 0,
            width = conf.width,
            height = conf.height,
        }
    }
    return main_node
}



test_tree :: proc(menu : ^Menu, tree: ^Node){
    main_node := tree
    container := new_container(
        "div1",
        false
    )
    container.color = color_green
    container.layout = Layout{
        width = Size_Value{
            mode = .Percent,
            value = 50,
        },
        height = Size_Value{
            mode = .Percent,
            value = 50,
        }
    }
    addChild(main_node,container)

    container2 := new_container(
        "div1",
        false
    )
    container2.color = color_red
    container2.layout = Layout{
        width = Size_Value{
            mode = .Percent,
            value = 50,
        },
        height = Size_Value{
            mode = .Percent,
            value = 50,
        }
    }
    addChild(main_node,container2)
}

