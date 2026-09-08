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
