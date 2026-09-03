package main

import d3d "vendor:directx/d3d11"

Size_Mode:: enum{
    Auto,
    Pixels,
    Percent,
    Flex,
}

Color :: [4]f32


Layout_Direction :: enum {
    Row,
    Column,
}

Border_Measurements :: struct {
    top, bottom, left, right: f32,
}

Border :: struct {
    color: Color,
    sides: Border_Measurements,
}

Text_Alignment :: enum{
    left,
    right,
    center,
}

Text_Style :: struct{
    alignment : Text_Alignment,
    color : Color,
    font_size : f32,
}

Layout :: struct {
    width:  Size_Value,
    height: Size_Value,

    direction: Layout_Direction,
    wrap: bool,

    has_border : bool,
    border: Border,

    flex_grow:   f32,
    flex_shrink: f32,

    min_width:  f32,
    min_height: f32,
    max_width:  f32,
    max_height: f32,

    
    gap:     f32,
    padding: Padding,
}

Padding :: struct {
    left, top, right, bottom: f32,
}

Size_Value :: struct{
    mode: Size_Mode,
    value: f32,
}




NodeType :: enum{
    Container = 0,
    List = 1,
    Icon = 2,
    Text = 3,
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

    text : string,
    texture : ^d3d.IShaderResourceView
}

addChild :: proc(parent: ^Node, child: Node){
    append(&parent.children, child)
}


new_container :: proc(id:string, static: bool)->Node{
    cntnr : Node = Node{
        id = id,
        type = .Container,
        static = static,
    }
    
    return cntnr
}


new_text :: proc(id: string, static: bool, text:string, )
new_app_list :: proc(
    id: string,
    static: bool,
    menu: ^Menu,
) -> Node {

    list := new_container(id, static)

    list.type = .List

    list.layout = Layout{
        width = Size_Value{
            mode  = .Flex,
            value = 1,
        },
        height = Size_Value{
            mode  = .Flex,
            value = 1,
        },
        direction = .Column,
    }

    add_border(
        &list,
        Border{
            color = color_white,
            sides = {right = 2},
        }
    )

    start_apps := get_start_apps(menu)

    for app in start_apps {
        // The entire application row
        app_row := new_container(app.name, false)

        app_row.layout = Layout{
            direction = .Row,
            width = Size_Value{
                mode  = .Percent,
                value = 100,
            },

            height = Size_Value{
                mode  = .Pixels,
                value = 72,
            },
        }

        app_row.text = app.name

        // The actual icon
        icon := Node{
            id      = app.name,
            type    = .Icon,
            texture = app.icon,

            layout = Layout{
                width = Size_Value{
                    mode  = .Pixels,
                    value = 64,
                },

                height = Size_Value{
                    mode  = .Pixels,
                    value = 64,
                },
            },
        }

        addChild(&app_row, icon)
        addChild(&list, app_row)
    }

    return list
}

add_border :: proc(node:^Node, border: Border){
    node.layout.has_border = true
    node.layout.border = border
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
    
    addChild(
        main_node,
        new_app_list("test-list",
        false,
        menu))

}

