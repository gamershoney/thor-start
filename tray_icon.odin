package main

import "base:runtime"
import "core:log"
import windows "core:sys/windows"

WM_THOR_TRAY_ICON :: windows.UINT(windows.WM_APP + 3)

THOR_TRAY_ICON_ID      :: windows.UINT(1)
THOR_TRAY_OPEN         :: windows.UINT_PTR(1001)
THOR_TRAY_RESTART      :: windows.UINT_PTR(1002)
THOR_TRAY_EXIT         :: windows.UINT_PTR(1003)

taskbar_created_message: windows.UINT
tray_icon_added: bool

make_tray_icon_data :: proc(hwnd: windows.HWND, icon: windows.HICON) -> windows.NOTIFYICONDATAW {
    data := windows.NOTIFYICONDATAW{
        cbSize = size_of(windows.NOTIFYICONDATAW),
        hWnd = hwnd,
        uID = THOR_TRAY_ICON_ID,
        uFlags = windows.NIF_MESSAGE | windows.NIF_ICON | windows.NIF_TIP,
        uCallbackMessage = WM_THOR_TRAY_ICON,
        hIcon = icon,
    }
    _ = windows.utf8_to_wstring(data.szTip[:], "Thor Start")
    return data
}

add_tray_icon :: proc(hwnd: windows.HWND) -> bool {
    if hwnd == nil do return false

    icon := windows.LoadIconW(
        hinstance,
        cast(cstring16)windows.MAKEINTRESOURCEW(101),
    )
    if icon == nil {
        icon = windows.LoadIconW(
            nil,
            cast(cstring16)windows.MAKEINTRESOURCEW(32512),
        )
    }
    if icon == nil {
        log.warnf("could not load a notification-area icon (Win32 error %d)", windows.GetLastError())
        return false
    }

    data := make_tray_icon_data(hwnd, icon)
    if !windows.Shell_NotifyIconW(windows.NIM_ADD, &data) {
        log.warnf("could not add the notification-area icon (Win32 error %d)", windows.GetLastError())
        tray_icon_added = false
        return false
    }

    tray_icon_added = true
    return true
}

init_tray_icon :: proc(hwnd: windows.HWND) -> bool {
    taskbar_created_message = windows.RegisterWindowMessageW("TaskbarCreated")
    return add_tray_icon(hwnd)
}

remove_tray_icon :: proc(hwnd: windows.HWND) {
    if !tray_icon_added || hwnd == nil do return

    data := windows.NOTIFYICONDATAW{
        cbSize = size_of(windows.NOTIFYICONDATAW),
        hWnd = hwnd,
        uID = THOR_TRAY_ICON_ID,
    }
    _ = windows.Shell_NotifyIconW(windows.NIM_DELETE, &data)
    tray_icon_added = false
}

restart_thor :: proc(hwnd: windows.HWND) -> bool {
    executable: [windows.MAX_PATH_WIDE]u16
    count := windows.GetModuleFileNameW(nil, &executable[0], windows.DWORD(len(executable)))
    if count == 0 || int(count) >= len(executable) {
        log.errorf("could not find the Thor Start executable for restart (Win32 error %d)", windows.GetLastError())
        return false
    }

    result := windows.ShellExecuteW(
        nil,
        nil,
        cstring16(&executable[0]),
        nil,
        nil,
        windows.SW_SHOWNORMAL,
    )
    if uintptr(result) <= 32 {
        log.errorf("could not restart Thor Start (ShellExecute error %d)", uintptr(result))
        return false
    }

    windows.PostMessageW(hwnd, windows.WM_CLOSE, 0, 0)
    return true
}

show_tray_menu :: proc(hwnd: windows.HWND) {
    context = runtime.default_context()

    menu := windows.CreatePopupMenu()
    if menu == nil {
        log.warnf("could not create the notification-area menu (Win32 error %d)", windows.GetLastError())
        return
    }
    defer windows.DestroyMenu(menu)

    _ = windows.AppendMenuW(menu, windows.MF_STRING, THOR_TRAY_OPEN, "Open Thor Start")
    _ = windows.AppendMenuW(menu, windows.MF_SEPARATOR, 0, nil)
    _ = windows.AppendMenuW(menu, windows.MF_STRING, THOR_TRAY_RESTART, "Restart Thor Start")
    _ = windows.AppendMenuW(menu, windows.MF_STRING, THOR_TRAY_EXIT, "Exit Thor Start")

    point: windows.POINT
    if !windows.GetCursorPos(&point) do return

    // SetForegroundWindow and the trailing WM_NULL give a notification-area
    // popup the same dismissal behavior as Explorer's own menus.
    _ = windows.SetForegroundWindow(hwnd)
    command := windows.TrackPopupMenu(
        menu,
        windows.TPM_RIGHTBUTTON | windows.TPM_RETURNCMD | windows.TPM_NONOTIFY,
        point.x,
        point.y,
        0,
        hwnd,
        nil,
    )
    _ = windows.PostMessageW(hwnd, windows.WM_NULL, 0, 0)

    switch windows.UINT_PTR(command) {
    case THOR_TRAY_OPEN:
        set_menu_hidden(false)
    case THOR_TRAY_RESTART:
        _ = restart_thor(hwnd)
    case THOR_TRAY_EXIT:
        windows.PostMessageW(hwnd, windows.WM_CLOSE, 0, 0)
    }
}

handle_tray_callback :: proc(hwnd: windows.HWND, l_param: windows.LPARAM) {
    event := windows.UINT(l_param)
    switch event {
    case windows.WM_CONTEXTMENU, windows.WM_RBUTTONUP:
        show_tray_menu(hwnd)
    case windows.WM_LBUTTONDBLCLK:
        toggle_menu_visibility()
    }
}
