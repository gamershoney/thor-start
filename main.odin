package main

import "core:fmt"
import windows "core:sys/windows"

keyboard_proc :: proc "stdcall" (
	nCode: i32,
	wParam: windows.WPARAM,
	lParam: windows.LPARAM,
) -> windows.LRESULT {
    if nCode < 0 {
        return windows.CallNextHookEx(nil, nCode, wParam, lParam)
    }
    if code >= 0{

    }
	return 1
}

error :: distinct string


bindWinKey :: proc() -> error{
	hook: windows.HHOOK
	hook = windows.SetWindowsHookExW(windows.WH_KEYBOARD_LL, keyboard_proc, nil, 0)
    if hook == nil{
        return "error: could not set windows hook (bindWinKey)"
    }
    return ""
}

main :: proc() {

}
