package main

import "base:runtime"
import "core:fmt"
import windows "core:sys/windows"

keyboard_keys_down: [256]bool
non_win_keys_down: int
win_keys_down: int
win_press_is_standalone: bool

// Spots either Windows key so left-handed and right-handed thunder both count.
is_win_key :: proc(key: u32) -> bool {
	return key == windows.VK_LWIN || key == windows.VK_RWIN
}

// Guards the keyboard hook with the focus of a caffeinated hall monitor.
keyboard_proc :: proc "stdcall" (
	code: i32,
	w_param: windows.WPARAM,
	l_param: windows.LPARAM,
) -> windows.LRESULT {
	context = runtime.default_context()
	if code < 0 {
		return windows.CallNextHookEx(nil, code, w_param, l_param)
	}

	is_key_down := w_param == windows.WM_KEYDOWN || w_param == windows.WM_SYSKEYDOWN
	is_key_up := w_param == windows.WM_KEYUP || w_param == windows.WM_SYSKEYUP
	if !is_key_down && !is_key_up {
		return windows.CallNextHookEx(nil, code, w_param, l_param)
	}

	kbd := cast(^windows.KBDLLHOOKSTRUCT)(cast(uintptr)l_param)
	key := kbd.vkCode
	if key >= len(keyboard_keys_down) {
		return windows.CallNextHookEx(nil, code, w_param, l_param)
	}

	key_index := int(key)
	already_down := keyboard_keys_down[key_index]

	if is_key_down {
		if !already_down {
			keyboard_keys_down[key_index] = true

			if is_win_key(key) {
				if win_keys_down == 0 {
					win_press_is_standalone = non_win_keys_down == 0
				} else {
					win_press_is_standalone = false
				}
				win_keys_down += 1
			} else {
				non_win_keys_down += 1
				if win_keys_down > 0 {
					win_press_is_standalone = false
				}
			}
		}

		return windows.CallNextHookEx(nil, code, w_param, l_param)
	}

	if already_down {
		keyboard_keys_down[key_index] = false

		if is_win_key(key) {
			win_keys_down -= 1
			if win_keys_down == 0 && win_press_is_standalone {
				win_press_is_standalone = false
				if global_state != nil && global_state.menu.window.hwnd != nil {
					windows.PostMessageW(
						global_state.menu.window.hwnd,
						WM_THOR_TOGGLE_MENU,
						0,
						0,
					)
				}
				return 1
			}
		} else if non_win_keys_down > 0 {
			non_win_keys_down -= 1
		}
	}

	return windows.CallNextHookEx(nil, code, w_param, l_param)
}

// Gives failures their own identity so they can grow beyond being ordinary strings.
Win_Key_Error :: distinct string


// Persuades the Windows key to work for Thor now, because career growth matters.
bind_win_key :: proc() -> (windows.HHOOK, Win_Key_Error) {
	hook: windows.HHOOK
	hook = windows.SetWindowsHookExW(windows.WH_KEYBOARD_LL, keyboard_proc, nil, 0)
	if hook == nil {
		error_code := windows.GetLastError()
		fmt.print(error_code)
		return nil, "error: could not set Windows hook (bind_win_key)"
	}
	
	return hook,""
}
