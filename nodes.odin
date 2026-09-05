package main

import d3d "vendor:directx/d3d11"



// Lets every size choose its destiny: fixed, flexible, automatic, or boldly percentage-based.
Size_Mode:: enum{
    Auto,
    Pixels,
    Percent,
    Flex,
}

// Packs four heroic channels into one tiny uniform that refuses to be beige by accident.
Color :: [4]f32


// Points children toward their future, whether that journey is sideways or downward.
Layout_Direction :: enum {
    Row,
    Column,
}

// Gives each edge independent ambitions because symmetry is merely a suggestion.
Border_Measurements :: struct {
    top, bottom, left, right: f32,
}

// Dresses a node for success with color and four highly motivated edges.
Border :: struct {
    color: Color,
    sides: Border_Measurements,
}

// Helps text pick a side—or achieve enlightened centering when office politics get intense.
Text_Alignment :: enum{
    left,
    right,
    center,
}

// Coaches raw words into looking employable before they meet the renderer.
Text_Style :: struct{
    alignment : Text_Alignment,
    color : Color,
    font_size : f32,
    text : string,
}

// Negotiates size, spacing, and boundaries like the world's most patient tiny architect.
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

// Protects content's personal space with four firm but supportive boundaries.
Padding :: struct {
    left, top, right, bottom: f32,
}

// Pairs a measurement strategy with the number brave enough to carry it out.
Size_Value :: struct{
    mode: Size_Mode,
    value: f32,
}




// Assigns every node a role so nobody wanders onto the render stage without a costume.
NodeType :: enum{
    Container = 0,
    List = 1,
    Icon = 2,
    Text = 3,
}

// Defines a rectangular kingdom where width and height may rule with benevolence.
Rect :: struct{
    x,y : f32,
    width, height : f32,
}

// Unites layout, appearance, and children into one determined little UI organism.
Node :: struct{
    id: string,
    type: NodeType,
    children : [dynamic]Node,
    static: bool,
    layout: Layout,
    bounds : Rect,
    color  : Color,

    Event_Listeners : [dynamic]Action_CallBack,

    text_style: Text_Style,
    texture : ^d3d.IShaderResourceView
}



// Helps the UI family grow one carefully appended overachiever at a time.
addChild :: proc(parent: ^Node, child: Node){
    append(&parent.children, child)
}


// Builds an empty container with unlimited potential and absolutely no furniture.
new_container :: proc(id:string, static: bool)->Node{
    cntnr : Node = Node{
        id = id,
        type = .Container,
        static = static,
    }
    
    return cntnr
}

// Encourages a text node to become real and arrive dressed in its requested style.
new_text :: proc(id: string, static: bool, text_style: Text_Style) -> Node {
    return Node{
        id = id,
        type = .Text,
        static = static,
        color = text_style.color,
        text_style = text_style,
    }
}
// Turns a pile of shortcuts into an orderly list that almost has its life together.
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

        highlight_on_hover(&app_row, &color_red)

        app_row.layout = Layout{
            direction = .Row,
            gap = 8,
            width = Size_Value{
                mode  = .Percent,
                value = 100,
            },

            height = Size_Value{
                mode  = .Pixels,
                value = 72,
            },
        }

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

        label := new_text(
            app.name,
            false,
            Text_Style{
                alignment = .left,
                color = color_white,
                font_size = 18,
                text = app.name,
            },
        )
        label.layout = Layout{
            width = Size_Value{
                mode = .Flex,
                value = 1,
            },
            height = Size_Value{
                mode = .Percent,
                value = 100,
            },
        }

        addChild(&app_row, icon)
        addChild(&app_row, label)
        addChild(&list, app_row)
    }

    return list
}

// Gives a node strong boundaries, a useful skill in both UI design and adulthood.
add_border :: proc(node:^Node, border: Border){
    node.layout.has_border = true
    node.layout.border = border
}

// Plants the root node and believes fiercely in the interface it will become.
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




// Sends the young tree into a practical trial by app list and cheers from the sidelines.
test_tree :: proc(menu : ^Menu, tree: ^Node){
    main_node := tree
    
    addChild(
        main_node,
        new_app_list("test-list",
        false,
        menu))

}

