package main

import d3d "vendor:directx/d3d11"
import fontstash "vendor:fontstash"

// Carries geometry through life with coordinates, dimensions, color, and suspicious confidence.
Position:: struct{
    position : [3]f32,
    width: f32,
    height: f32,
    color: [4]f32,
}

// Teaches every child where it belongs without crushing its flex-based dreams.
create_layout :: proc(node: ^Node) {
    space := node.bounds

    border := Border_Measurements{}
    if node.layout.has_border {
        border = node.layout.border.sides

        if border.top < 0 do border.top = 0
        if border.bottom < 0 do border.bottom = 0
        if border.left < 0 do border.left = 0
        if border.right < 0 do border.right = 0
    }

    content_x := space.x + border.left + node.layout.padding.left
    content_y := space.y + border.top + node.layout.padding.top
    content_width := space.width -
        border.left - border.right -
        node.layout.padding.left - node.layout.padding.right
    content_height := space.height -
        border.top - border.bottom -
        node.layout.padding.top - node.layout.padding.bottom

    if content_width < 0 {
        content_width = 0
    }
    if content_height < 0 {
        content_height = 0
    }

    fixed_width: f32
    fixed_height: f32
    total_flex_width: f32
    total_flex_height: f32

    for child in node.children {
        #partial switch child.layout.width.mode {
        case .Pixels:
            fixed_width += child.layout.width.value
        case .Percent:
            fixed_width += content_width * child.layout.width.value / 100.0
        case .Flex:
            total_flex_width += child.layout.width.value
        case .Auto:
            fixed_width += child.bounds.width
        }

        #partial switch child.layout.height.mode {
        case .Pixels:
            fixed_height += child.layout.height.value
        case .Percent:
            fixed_height += content_height * child.layout.height.value / 100.0
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

    remaining_width := content_width - fixed_width - gap_width
    remaining_height := content_height - fixed_height - gap_height
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
            child.bounds.width = content_width * child.layout.width.value / 100.0
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
            child.bounds.height = content_height * child.layout.height.value / 100.0
        case .Flex:
            if total_flex_height > 0 {
                child.bounds.height =
                    remaining_height * child.layout.height.value / total_flex_height
            }
        }
    }

    cursor_x := content_x
    cursor_y := content_y
    line_extent: f32

    for &child in node.children {
        if node.layout.direction == .Row {
            if node.layout.wrap &&
               cursor_x > content_x &&
               cursor_x + child.bounds.width > content_x + content_width {
                cursor_x = content_x
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
               cursor_y > content_y &&
               cursor_y + child.bounds.height > content_y + content_height {
                cursor_y = content_y
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

// Marches through the UI family tree and makes sure every node gets its moment on screen.
draw_Tree :: proc(menu:^Menu, node: ^Node){

    for &callback in node.Event_Listeners {
        callback.node = node

        append(
            &Event_Listeners,
            callback
        )
    }

    switch node.type{
        case .Container, .List:
            draw_rect(menu,node)
        
        case .Icon:
            draw_icon(menu,node)

        case .Text:
            draw_text(menu,node)
    }

    if node.layout.has_border {
        draw_border(menu,node)
    }
    for &child in node.children{
        draw_Tree(menu,&child)
    }


}

// Turns humble strings into triangles because even words deserve a GPU-powered glow-up.
draw_text :: proc(menu:^Menu, node: ^Node){
    font_ctx := &menu.window.font_renderer.ctx
    fontstash.SetSize(font_ctx, node.text_style.font_size)
    fontstash.SetAlignVertical(font_ctx, .MIDDLE)

    text_x := node.bounds.x
    #partial switch node.text_style.alignment {
    case .left:
        fontstash.SetAlignHorizontal(font_ctx, .LEFT)
    case .right:
        fontstash.SetAlignHorizontal(font_ctx, .RIGHT)
        text_x += node.bounds.width
    case .center:
        fontstash.SetAlignHorizontal(font_ctx, .CENTER)
        text_x += node.bounds.width * 0.5
    }

    iter := fontstash.TextIterInit(
        font_ctx,
        text_x,
        node.bounds.y + node.bounds.height * 0.5,
        node.text_style.text,
    )

    quad : fontstash.Quad
    first := u32(len(menu.window.vertex_renderer.vertices))

   for fontstash.TextIterNext(
    &menu.window.font_renderer.ctx,
    &iter,
    &quad
   ){
        verts := [6]Vertex{
            {{quad.x0, quad.y0, 0}, node.text_style.color, {quad.s0, quad.t0}},
            {{quad.x0, quad.y1, 0}, node.text_style.color, {quad.s0, quad.t1}},
            {{quad.x1, quad.y0, 0}, node.text_style.color, {quad.s1, quad.t0}},

            {{quad.x1, quad.y0, 0}, node.text_style.color, {quad.s1, quad.t0}},
            {{quad.x0, quad.y1, 0}, node.text_style.color, {quad.s0, quad.t1}},
            {{quad.x1, quad.y1, 0}, node.text_style.color, {quad.s1, quad.t1}},
        }

        append(&menu.window.vertex_renderer.vertices,
        ..verts[:])

   }

   update_font_atlas(menu)
   vertex_count := u32(len(menu.window.vertex_renderer.vertices)) - first

    if vertex_count > 0 {
        append(
            &menu.window.vertex_renderer.commands,
            Render_Command{
                kind = .Text,
                first_vertex = first,
                vertex_count = vertex_count,
                texture = menu.window.font_renderer.srv,
            },
        )
    }
}

// Renders healthy boundaries one independently opinionated edge at a time.
draw_border :: proc (menu:^Menu,node: ^Node){
    x0 := node.bounds.x
    y0 := node.bounds.y

    x1 := node.bounds.x + node.bounds.width
    y1 := node.bounds.y + node.bounds.height

    sides := node.layout.border.sides
    color := node.layout.border.color

    // left
    if sides.left > 0 {
        draw_border_line(
            Rect{
                x      = x0,
                y      = y0 + sides.top,
                width  = sides.left,
                height = node.bounds.height - sides.top - sides.bottom,
            },
            color,
            menu,
        )
    }

    // right
    if sides.right > 0 {
        draw_border_line(
            Rect{
                x      = x1 - sides.right,
                y      = y0 + sides.top,
                width  = sides.right,
                height = node.bounds.height - sides.top - sides.bottom,
            },
            color,
            menu,
        )
    }

    // top
    if sides.top > 0 {
        draw_border_line(
            Rect{
                x      = x0,
                y      = y0,
                width  = node.bounds.width,
                height = sides.top,
            },
            color,
            menu,
        )
    }

    // bottom
    if sides.bottom > 0 {
        draw_border_line(
            Rect{
                x      = x0,
                y      = y1 - sides.bottom,
                width  = node.bounds.width,
                height = sides.bottom,
            },
            color,
            menu,
        )
    }
}


// Converts one border edge into six vertices of unwavering rectangular determination.
draw_border_line :: proc(rect:Rect, color:Color,menu:^Menu){
    if rect.width <= 0 || rect.height <= 0 {
        return
    }

    x0 := rect.x
    y0 := rect.y
    x1 := rect.x + rect.width
    y1 := rect.y + rect.height

    first := u32(len(menu.window.vertex_renderer.vertices))


    verts := [6]Vertex{
    {
        {x0, y0, 0},
        color,
        {0,0},
    },
    {
        {x0, y1, 0},
        color,
        {0,0},
    },
    {
        {x1, y0, 0},
        color,
        {0,0},
    },

    {
        {x1, y0, 0},
        color,
        {0,0},
    },
    {
        {x0, y1, 0},
        color,
        {0,0},
    },
    {
        {x1, y1, 0},
        color,
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


// Fills a node's rectangle with color and the quiet pride of two well-formed triangles.
draw_rect:: proc (menu:^Menu, node: ^Node){
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


// Gives an icon six vertices, sensible UVs, and a fair shot at visual greatness.
draw_icon :: proc(menu: ^Menu, node: ^Node){

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
