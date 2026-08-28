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
