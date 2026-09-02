package main

import d3d "vendor:directx/d3d11"
Position:: struct{
    position : [3]f32,
    width: f32,
    height: f32,
    color: [4]f32,
}

create_layout :: proc(node: ^Node) {
    space := node.bounds

    fixed_width: f32
    fixed_height: f32
    total_flex_width: f32
    total_flex_height: f32

    for child in node.children {
        #partial switch child.layout.width.mode {
        case .Pixels:
            fixed_width += child.layout.width.value
        case .Percent:
            fixed_width += space.width * child.layout.width.value / 100.0
        case .Flex:
            total_flex_width += child.layout.width.value
        case .Auto:
            fixed_width += child.bounds.width
        }

        #partial switch child.layout.height.mode {
        case .Pixels:
            fixed_height += child.layout.height.value
        case .Percent:
            fixed_height += space.height * child.layout.height.value / 100.0
        case .Flex:
            total_flex_height += child.layout.height.value
        case .Auto:
            fixed_height += child.bounds.height
        }
    }

    gap_width: f32
    gap_height: f32
    if len(node.children) > 1 {
        gap_total := node.layout.gap * f32(len(node.children) - 1)
        if node.layout.direction == .Row {
            gap_width = gap_total
        } else {
            gap_height = gap_total
        }
    }

    remaining_width := space.width - fixed_width - gap_width
    remaining_height := space.height - fixed_height - gap_height
    if remaining_width < 0 {
        remaining_width = 0
    }
    if remaining_height < 0 {
        remaining_height = 0
    }

    // Resolve sizes first so wrapping can inspect each child's extent.
    for &child in node.children {
        #partial switch child.layout.width.mode {
        case .Pixels:
            child.bounds.width = child.layout.width.value
        case .Percent:
            child.bounds.width = space.width * child.layout.width.value / 100.0
        case .Flex:
            if total_flex_width > 0 {
                child.bounds.width =
                    remaining_width * child.layout.width.value / total_flex_width
            }
        }

        #partial switch child.layout.height.mode {
        case .Pixels:
            child.bounds.height = child.layout.height.value
        case .Percent:
            child.bounds.height = space.height * child.layout.height.value / 100.0
        case .Flex:
            if total_flex_height > 0 {
                child.bounds.height =
                    remaining_height * child.layout.height.value / total_flex_height
            }
        }
    }

    cursor_x := space.x
    cursor_y := space.y
    line_extent: f32

    for &child in node.children {
        if node.layout.direction == .Row {
            if node.layout.wrap &&
               cursor_x > space.x &&
               cursor_x + child.bounds.width > space.x + space.width {
                cursor_x = space.x
                cursor_y += line_extent + node.layout.gap
                line_extent = 0
            }

            child.bounds.x = cursor_x
            child.bounds.y = cursor_y
            cursor_x += child.bounds.width + node.layout.gap
            if child.bounds.height > line_extent {
                line_extent = child.bounds.height
            }
        } else {
            if node.layout.wrap &&
               cursor_y > space.y &&
               cursor_y + child.bounds.height > space.y + space.height {
                cursor_y = space.y
                cursor_x += line_extent + node.layout.gap
                line_extent = 0
            }

            child.bounds.x = cursor_x
            child.bounds.y = cursor_y
            cursor_y += child.bounds.height + node.layout.gap
            if child.bounds.width > line_extent {
                line_extent = child.bounds.width
            }
        }
    }

    for &child in node.children {
        create_layout(&child)
    }
}

draw_Tree :: proc(menu:^Menu, node: ^Node){
    switch node.type{
        case .Container, .List:
            draw_rect(menu,node)
        
        case .Icon:
            draw_icon(menu,node)
    }

    for &child in node.children{
        draw_Tree(menu,&child)
    }


}

draw_rect:: proc (menu:^Menu, node: ^Node){
    use_solid_shader(menu)
    x0 := node.bounds.x
    y0 := node.bounds.y

    x1 := node.bounds.x + node.bounds.width
    y1 := node.bounds.y + node.bounds.height

    first := u32(len(menu.window.vertex_renderer.vertices))

    verts := [6]Vertex{
    {
        {x0, y0, 0},
        node.color,
        {0,0},
    },
    {
        {x0, y1, 0},
        node.color,
        {0,0},
    },
    {
        {x1, y0, 0},
        node.color,
        {0,0},
    },

    {
        {x1, y0, 0},
        node.color,
        {0,0},
    },
    {
        {x0, y1, 0},
         node.color,
        {0,0},
    },
    {
        {x1, y1, 0},
         node.color,
        {0,0},
    },
    }

    append(
        &menu.window.vertex_renderer.vertices,
         ..verts[:]
        )
    append(
        &menu.window.vertex_renderer.commands,
        Render_Command{
            kind = .Solid,
            first_vertex = first,
            vertex_count = 6,
        }
    )

}


draw_icon :: proc(menu: ^Menu, node: ^Node){
    use_icon_shader(menu)

    x0 := node.bounds.x
    y0 := node.bounds.y
    x1 := x0 + node.bounds.width
    y1 := y0 + node.bounds.height

    first := u32(len(menu.window.vertex_renderer.vertices))

    white := Color{1, 1, 1, 1}

    verts := [6]Vertex{
        {
            position = {x0, y0, 0},
            color    = white,
            uv       = {0, 0},
        },
        {
            position = {x0, y1, 0},
            color    = white,
            uv       = {0, 1},
        },
        {
            position = {x1, y0, 0},
            color    = white,
            uv       = {1, 0},
        },

        {
            position = {x1, y0, 0},
            color    = white,
            uv       = {1, 0},
        },
        {
            position = {x0, y1, 0},
            color    = white,
            uv       = {0, 1},
        },
        {
            position = {x1, y1, 0},
            color    = white,
            uv       = {1, 1},
        },
    }

    append(
        &menu.window.vertex_renderer.vertices,
        ..verts[:],
    )

    append(
        &menu.window.vertex_renderer.commands,
        Render_Command{
            kind         = .Texture,
            first_vertex = first,
            vertex_count = 6,
            texture      = node.texture,
        },
    )
}