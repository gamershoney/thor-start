package main

import d3d "vendor:directx/d3d11"
Position:: struct{
    position : [3]f32,
    width: f32,
    height: f32,
    color: [4]f32,
}

create_layout :: proc(node:^Node){
    space : Rect = node.bounds

    x: f32 = node.bounds.x
    y: f32 = node.bounds.y

    total_flex_width: f32
    total_flex_height : f32

    
    remaining_percent_width: f32 = 100
    remaining_percent_height: f32 = 100

    //Get flex ratios
    for child in node.children{
        #partial switch child.layout.width.mode{
            case .Percent:
                remaining_percent_width += child.layout.width.value

            case .Flex:
                total_flex_width += child.layout.width.value
        }
        #partial switch child.layout.height.mode{
            case .Percent:
                remaining_percent_height += child.layout.height.value

            case .Flex:
                total_flex_height += child.layout.height.value
        }
    }

    //Set actual space
    for &child in node.children{
        #partial switch child.layout.width.mode{
            case .Percent:
                if remaining_percent_width - child.layout.width.value < 0{
                    child.bounds.width = remaining_percent_width *
                    space.width
                    remaining_percent_width = 0

                }

            case .Flex:
                child.bounds.width = (child.layout.width.value/total_flex_width) * 
                space.width
                child.bounds.x = x
                x += child.bounds.width
        }
        #partial switch child.layout.height.mode{
            case .Flex:
                child.bounds.height = (child.layout.height.value/total_flex_height) *
                space.height
                child.bounds.y = y
                y += child.bounds.height
        }
    }
}

draw_Tree :: proc(menu:^Menu, node: ^Node){
    draw_rect(menu,node);
    for &child in node.children{
        draw_Tree(menu,&child)
    }


}

draw_rect:: proc (menu:^Menu, node: ^Node){
    x0 := node.bounds.x
    y0 := node.bounds.y

    x1 := node.bounds.x + node.bounds.width
    y1 := node.bounds.y + node.bounds.height

    verts := [6]Vertex{
    {{x0, y0, 0}, node.color},
    {{x0, y1, 0}, node.color},
    {{x1, y0, 0}, node.color},

    {{x1, y0, 0}, node.color},
    {{x0, y1, 0}, node.color},
    {{x1, y1, 0}, node.color},
    }

    append(&menu.window.vertex_renderer.vertices, ..verts[:])

}


