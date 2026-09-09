package main

import "core:testing"
import windows "core:sys/windows"

@(test)
test_tray_icon_data_routes_messages_and_sets_tip :: proc(t: ^testing.T) {
    hwnd := cast(windows.HWND)uintptr(1)
    icon := cast(windows.HICON)uintptr(2)
    data := make_tray_icon_data(hwnd, icon)

    testing.expect_value(t, data.hWnd, hwnd)
    testing.expect_value(t, data.hIcon, icon)
    testing.expect_value(t, data.uID, THOR_TRAY_ICON_ID)
    testing.expect_value(t, data.uCallbackMessage, WM_THOR_TRAY_ICON)
    testing.expect(t, (data.uFlags & windows.NIF_MESSAGE) != 0)
    testing.expect(t, (data.uFlags & windows.NIF_ICON) != 0)
    testing.expect(t, (data.uFlags & windows.NIF_TIP) != 0)
    testing.expect_value(t, data.szTip[0], u16('T'))
    testing.expect_value(t, data.szTip[9], u16('t'))
    testing.expect_value(t, data.szTip[10], u16(0))
}
