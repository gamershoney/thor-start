package main

import "base:runtime"
import "core:fmt"
import windows "core:sys/windows"

keyboard_proc :: proc "stdcall" (
	nCode: i32,
	wParam: windows.WPARAM,
	lParam: windows.LPARAM,
) -> windows.LRESULT {
    context = runtime.default_context()
	if nCode < 0 {
		return windows.CallNextHookEx(nil, nCode, wParam, lParam)
	}
	if nCode >= 0 {
		if wParam == windows.WM_KEYUP {
            raw_ptr := cast(uintptr)lParam
            kbd := cast(^windows.KBDLLHOOKSTRUCT)(raw_ptr)
            keypress := kbd.vkCode
            fmt.println(keypress)
            if keypress == 91{
                fmt.println("winkey pressed")
                return 1
            }
		}
	}
	return windows.CallNextHookEx(nil, nCode, wParam, lParam)
}

error :: distinct string


bindWinKey :: proc() -> error {
	hook: windows.HHOOK
	hook = windows.SetWindowsHookExW(windows.WH_KEYBOARD_LL, keyboard_proc, nil, 0)
	if hook == nil {
        errcode := windows.GetLastError()
        fmt.print(errcode)
		return "error: could not set windows hook (bindWinKey)"
	}
    defer windows.UnhookWindowsHookEx(hook)
    msg: windows.MSG
    for windows.GetMessageW(&msg, nil, 0,0) > 0 {
        windows.TranslateMessage(&msg)
        windows.DispatchMessageW(&msg)
    }
    return ""
}

main :: proc() {

    
    err := bindWinKey()
    fmt.println(err)

}
