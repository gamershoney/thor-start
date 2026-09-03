package main

import "core:testing"

make_test_child :: proc(width, height: f32) -> Node {
    return Node{
        layout = Layout{
            width = Size_Value{mode = .Pixels, value = width},
            height = Size_Value{mode = .Pixels, value = height},
        },
    }
}

@(test)
layout_row_wraps_to_next_line :: proc(t: ^testing.T) {
    root := Node{
        layout = Layout{
            direction = .Row,
            wrap = true,
            gap = 5,
        },
        bounds = Rect{width = 100, height = 100},
    }
    defer delete(root.children)

    addChild(&root, make_test_child(45, 20))
    addChild(&root, make_test_child(45, 20))
    addChild(&root, make_test_child(45, 20))

    create_layout(&root)

    testing.expect_value(t, root.children[0].bounds.x, f32(0))
    testing.expect_value(t, root.children[0].bounds.y, f32(0))
    testing.expect_value(t, root.children[1].bounds.x, f32(50))
    testing.expect_value(t, root.children[1].bounds.y, f32(0))
    testing.expect_value(t, root.children[2].bounds.x, f32(0))
    testing.expect_value(t, root.children[2].bounds.y, f32(25))
}

@(test)
layout_column_wraps_to_next_line :: proc(t: ^testing.T) {
    root := Node{
        layout = Layout{
            direction = .Column,
            wrap = true,
            gap = 5,
        },
        bounds = Rect{width = 100, height = 100},
    }
    defer delete(root.children)

    addChild(&root, make_test_child(20, 45))
    addChild(&root, make_test_child(20, 45))
    addChild(&root, make_test_child(20, 45))

    create_layout(&root)

    testing.expect_value(t, root.children[0].bounds.x, f32(0))
    testing.expect_value(t, root.children[0].bounds.y, f32(0))
    testing.expect_value(t, root.children[1].bounds.x, f32(0))
    testing.expect_value(t, root.children[1].bounds.y, f32(50))
    testing.expect_value(t, root.children[2].bounds.x, f32(25))
    testing.expect_value(t, root.children[2].bounds.y, f32(0))
}

@(test)
layout_row_respects_padding :: proc(t: ^testing.T) {
    root := Node{
        layout = Layout{
            direction = .Row,
            wrap = true,
            gap = 5,
            padding = Padding{left = 10, top = 8, right = 10, bottom = 8},
        },
        bounds = Rect{x = 4, y = 6, width = 100, height = 100},
    }
    defer delete(root.children)

    addChild(&root, make_test_child(35, 20))
    addChild(&root, make_test_child(35, 20))
    addChild(&root, make_test_child(35, 20))

    create_layout(&root)

    testing.expect_value(t, root.children[0].bounds.x, f32(14))
    testing.expect_value(t, root.children[0].bounds.y, f32(14))
    testing.expect_value(t, root.children[1].bounds.x, f32(54))
    testing.expect_value(t, root.children[1].bounds.y, f32(14))
    testing.expect_value(t, root.children[2].bounds.x, f32(14))
    testing.expect_value(t, root.children[2].bounds.y, f32(39))
}

@(test)
layout_column_respects_padding :: proc(t: ^testing.T) {
    root := Node{
        layout = Layout{
            direction = .Column,
            wrap = true,
            gap = 5,
            padding = Padding{left = 10, top = 8, right = 10, bottom = 12},
        },
        bounds = Rect{x = 4, y = 6, width = 100, height = 100},
    }
    defer delete(root.children)

    addChild(&root, make_test_child(20, 35))
    addChild(&root, make_test_child(20, 35))
    addChild(&root, make_test_child(20, 35))

    create_layout(&root)

    testing.expect_value(t, root.children[0].bounds.x, f32(14))
    testing.expect_value(t, root.children[0].bounds.y, f32(14))
    testing.expect_value(t, root.children[1].bounds.x, f32(14))
    testing.expect_value(t, root.children[1].bounds.y, f32(54))
    testing.expect_value(t, root.children[2].bounds.x, f32(39))
    testing.expect_value(t, root.children[2].bounds.y, f32(14))
}

@(test)
layout_respects_individual_border_sides :: proc(t: ^testing.T) {
    root := Node{
        layout = Layout{
            direction = .Row,
            has_border = true,
            border = Border{
                color = color_red,
                sides = {top = 2, bottom = 4, left = 6, right = 8},
            },
            padding = Padding{left = 10, top = 20, right = 30, bottom = 40},
        },
        bounds = Rect{x = 5, y = 7, width = 200, height = 150},
    }
    defer delete(root.children)

    child := Node{
        layout = Layout{
            width = Size_Value{mode = .Percent, value = 100},
            height = Size_Value{mode = .Percent, value = 100},
        },
    }
    addChild(&root, child)

    create_layout(&root)

    testing.expect_value(t, root.children[0].bounds.x, f32(21))
    testing.expect_value(t, root.children[0].bounds.y, f32(29))
    testing.expect_value(t, root.children[0].bounds.width, f32(146))
    testing.expect_value(t, root.children[0].bounds.height, f32(84))
}

@(test)
border_renders_only_enabled_sides :: proc(t: ^testing.T) {
    menu := Menu{}
    defer delete(menu.window.vertex_renderer.vertices)
    defer delete(menu.window.vertex_renderer.commands)

    node := Node{
        bounds = Rect{x = 10, y = 20, width = 100, height = 50},
        layout = Layout{
            border = Border{
                color = color_red,
                sides = {top = 2, right = 3},
            },
        },
    }

    draw_border(&menu, &node)

    testing.expect_value(t, len(menu.window.vertex_renderer.commands), 2)
    testing.expect_value(t, len(menu.window.vertex_renderer.vertices), 12)
    testing.expect_value(t, menu.window.vertex_renderer.vertices[0].position[0], f32(107))
    testing.expect_value(t, menu.window.vertex_renderer.vertices[0].position[1], f32(22))
    testing.expect_value(t, menu.window.vertex_renderer.vertices[6].position[0], f32(10))
    testing.expect_value(t, menu.window.vertex_renderer.vertices[6].position[1], f32(20))
}
