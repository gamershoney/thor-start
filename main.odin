package main

import "core:fmt"
import windows "core:sys/windows"

keyboard_proc :: proc "stdcall" (
	nCode: i32,
	wParam: windows.WPARAM,
	lParam: windows.LPARAM,
) -> windows.LRESULT {
	return 1
}


bindWinKey :: proc() {
	hook: windows.HHOOK
	hook = windows.SetWindowsHookExW(windows.WH_KEYBOARD_LL, keyboard_proc, nil, 0)
}

main :: proc() {

}
