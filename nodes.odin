package main


Size_Mode:: enum{
    Auto,
    Pixels,
    Percent,
    Flex,
}

Layout :: struct {
    width:  f32,
    height: f32,

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
    value: Layout
}




NodeType :: enum{
    Container = 0,
}

Node :: struct{
    id: string,
    type: NodeType,
    children : [dynamic]Node,
    static: bool,
    size: Size_Value,
    color : color,
    position : [2]u32,
}

addChild :: proc(self: ^Node, child: Node){
    append(&self.children, child)
}

color :: [4]f32

color_red : color : {1,0,0,1}
color_blue : color : {0,0,1,1}
color_green : color : {0,1,0,1}

init_tree:: proc()->^Node{
    main_node : ^Node = &Node{
        id = "main_node",
        type = .Container,
        static = false,
        size = Size_Value{
            mode = .Percent,
            value = Layout{
                width = 100,
                height = 100,
            }
        }
    }
    return main_node
}

test_tree :: proc(menu : ^Menu){
    main_node := init_tree()

}