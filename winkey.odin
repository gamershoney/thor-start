package main

import "base:runtime"
import "core:fmt"
import windows "core:sys/windows"

// Guards the keyboard hook with the focus of a caffeinated hall monitor.
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
			if keypress == 91 {
				fmt.println("winkey pressed")
				return 1
			}
		}
	}
	return windows.CallNextHookEx(nil, nCode, wParam, lParam)
}

// Gives failures their own identity so they can grow beyond being ordinary strings.
error :: distinct string


// Persuades the Windows key to work for Thor now, because career growth matters.
bindWinKey :: proc() -> (windows.HHOOK,error) {
	hook: windows.HHOOK
	hook = windows.SetWindowsHookExW(windows.WH_KEYBOARD_LL, keyboard_proc, nil, 0)
	if hook == nil {
		errcode := windows.GetLastError()
		fmt.print(errcode)
		return nil, "error: could not set windows hook (bindWinKey)"
	}
	
	return hook,""
}
