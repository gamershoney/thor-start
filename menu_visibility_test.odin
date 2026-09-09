package main

import "core:testing"
import windows "core:sys/windows"

@(test)
menu_hides_only_on_deactivation :: proc(t: ^testing.T) {
    previous_state := global_state
    defer global_state = previous_state
    state := App_State{}
    global_state = &state

    // No native window is needed to verify the activation message/state path.
    wproc(nil, windows.WM_ACTIVATE, windows.WA_ACTIVE, 0)
    testing.expect(t, !state.hidden)
    wproc(nil, windows.WM_ACTIVATE, windows.WA_CLICKACTIVE, 0)
    testing.expect(t, !state.hidden)

    // The high word reports minimization; only the low word is activation.
    wproc(nil, windows.WM_ACTIVATE, windows.WPARAM(1 << 16), 0)
    testing.expect(t, state.hidden)
    wproc(nil, windows.WM_ACTIVATE, windows.WA_INACTIVE, 0)
    testing.expect(t, state.hidden)

    global_state = nil
    wproc(nil, windows.WM_ACTIVATE, windows.WA_INACTIVE, 0)
}

@(test)
taskbar_icon_click_toggles_menu_visibility :: proc(t: ^testing.T) {
    previous_state := global_state
    defer global_state = previous_state
    defer {
        thor_icon_click_armed = false
        thor_icon_click_target_hidden = false
    }
    state := App_State{hidden = true}
    global_state = &state

    result := overlay(nil, windows.WM_MOUSEACTIVATE, 0, 0)
    testing.expect_value(t, result, MA_NOACTIVATE)
    overlay(nil, windows.WM_LBUTTONDOWN, 0, 0)
    result = overlay(nil, windows.WM_LBUTTONUP, 0, 0)
    testing.expect_value(t, result, windows.LRESULT(0))
    testing.expect(t, !state.hidden)

    overlay(nil, windows.WM_MOUSEACTIVATE, 0, 0)
    overlay(nil, windows.WM_LBUTTONDOWN, 0, 0)

    // Mirror a focus-loss hide between the press and release. The release must
    // preserve the original hide intent instead of toggling the menu open again.
    state.hidden = true
    overlay(nil, windows.WM_LBUTTONUP, 0, 0)
    testing.expect(t, state.hidden)
}
