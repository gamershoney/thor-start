package main

import "base:runtime"
import "core:fmt"
import windows "core:sys/windows"

// Describes what the hook should do after the state machine judges one keyboard event.
Key_Hook_Action :: enum {
	Forward,
	Suppress,
	Begin_Shortcut,
	Toggle_Menu,
}

// Remembers physical key state separately from what Windows has actually been allowed to see.
Win_Key_State :: struct {
	keys_down: [256]bool,
	win_down_forwarded: [256]bool,
	non_win_keys_down: int,
	win_keys_down: int,
	standalone_candidate: bool,
	captured_win_key: u32,
}

win_key_state: Win_Key_State

KEYEVENTF_EXTENDEDKEY :: windows.DWORD(0x0001)
LLKHF_EXTENDED :: windows.DWORD(0x0001)
THOR_SYNTHETIC_INPUT :: windows.ULONG_PTR(0x54484f52)

// Spots either Windows key so left-handed and right-handed thunder both count.
is_win_key :: proc(key: u32) -> bool {
	return key == windows.VK_LWIN || key == windows.VK_RWIN
}

// Balances every withheld Win-down against either a private toggle or a forwarded shortcut.
track_key_event :: proc(state: ^Win_Key_State, key: u32, is_key_down: bool) -> Key_Hook_Action {
	if key >= len(state.keys_down) {
		return .Forward
	}

	key_index := int(key)
	already_down := state.keys_down[key_index]

	if is_key_down {
		if already_down {
			if is_win_key(key) && !state.win_down_forwarded[key_index] {
				return .Suppress
			}
			return .Forward
		}

		state.keys_down[key_index] = true
		if is_win_key(key) {
			state.win_keys_down += 1
			if state.win_keys_down == 1 {
				state.captured_win_key = key
				state.standalone_candidate = state.non_win_keys_down == 0
				if state.standalone_candidate {
					return .Suppress
				}

				state.win_down_forwarded[key_index] = true
				return .Forward
			}

			state.standalone_candidate = false
			captured_index := int(state.captured_win_key)
			if !state.win_down_forwarded[captured_index] {
				return .Begin_Shortcut
			}

			state.win_down_forwarded[key_index] = true
			return .Forward
		}

		state.non_win_keys_down += 1
		if state.win_keys_down > 0 {
			state.standalone_candidate = false
			captured_index := int(state.captured_win_key)
			if !state.win_down_forwarded[captured_index] {
				return .Begin_Shortcut
			}
		}
		return .Forward
	}

	if !already_down {
		return .Forward
	}
	state.keys_down[key_index] = false

	if !is_win_key(key) {
		if state.non_win_keys_down > 0 {
			state.non_win_keys_down -= 1
		}
		return .Forward
	}

	if state.win_keys_down > 0 {
		state.win_keys_down -= 1
	}
	was_forwarded := state.win_down_forwarded[key_index]
	state.win_down_forwarded[key_index] = false

	should_toggle :=
		key == state.captured_win_key &&
		state.standalone_candidate &&
		state.win_keys_down == 0

	if state.win_keys_down == 0 {
		state.standalone_candidate = false
		state.captured_win_key = 0
	}

	if should_toggle {
		return .Toggle_Menu
	}
	if !was_forwarded {
		return .Suppress
	}
	return .Forward
}

// Records which key-down events reached Windows after SendInput reports its progress.
finish_shortcut_forwarding :: proc(
	state: ^Win_Key_State,
	shortcut_key: u32,
	inputs_sent: int,
) {
	if inputs_sent >= 1 {
		state.win_down_forwarded[int(state.captured_win_key)] = true
	}
	if is_win_key(shortcut_key) {
		// The second Win-down is either synthesized or allowed through physically.
		state.win_down_forwarded[int(shortcut_key)] = true
	}
}

// Replays the withheld Win-down immediately before the key that turned it into a shortcut.
send_shortcut_key_down :: proc(win_key, shortcut_key, shortcut_flags: u32) -> int {
	shortcut_input_flags: windows.DWORD
	if shortcut_flags & LLKHF_EXTENDED != 0 {
		shortcut_input_flags |= KEYEVENTF_EXTENDEDKEY
	}

	inputs := [2]windows.INPUT{
		{
			type = .KEYBOARD,
			ki = {
				wVk = windows.WORD(win_key),
				dwFlags = KEYEVENTF_EXTENDEDKEY,
				dwExtraInfo = THOR_SYNTHETIC_INPUT,
			},
		},
		{
			type = .KEYBOARD,
			ki = {
				wVk = windows.WORD(shortcut_key),
				dwFlags = shortcut_input_flags,
				dwExtraInfo = THOR_SYNTHETIC_INPUT,
			},
		},
	}

	return int(windows.SendInput(
		windows.UINT(len(inputs)),
		raw_data(inputs[:]),
		windows.INT(size_of(windows.INPUT)),
	))
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
	if kbd.dwExtraInfo == THOR_SYNTHETIC_INPUT {
		return windows.CallNextHookEx(nil, code, w_param, l_param)
	}

	key := kbd.vkCode
	action := track_key_event(&win_key_state, key, is_key_down)

	switch action {
	case .Suppress:
		return 1
	case .Toggle_Menu:
		if global_state != nil && global_state.menu.window.hwnd != nil {
			windows.PostMessageW(
				global_state.menu.window.hwnd,
				WM_THOR_TOGGLE_MENU,
				0,
				0,
			)
		}
		return 1
	case .Begin_Shortcut:
		inputs_sent := send_shortcut_key_down(
			win_key_state.captured_win_key,
			key,
			kbd.flags,
		)
		finish_shortcut_forwarding(&win_key_state, key, inputs_sent)
		if inputs_sent == 2 {
			return 1
		}
	case .Forward:
	}

	return windows.CallNextHookEx(nil, code, w_param, l_param)
}

// Gives failures their own identity so they can grow beyond being ordinary strings.
Win_Key_Error :: distinct string


// Persuades the Windows key to work for Thor now, because career growth matters.
bind_win_key :: proc() -> (windows.HHOOK, Win_Key_Error) {
	win_key_state = {}
	hook: windows.HHOOK
	hook = windows.SetWindowsHookExW(windows.WH_KEYBOARD_LL, keyboard_proc, nil, 0)
	if hook == nil {
		error_code := windows.GetLastError()
		fmt.print(error_code)
		return nil, "error: could not set Windows hook (bind_win_key)"
	}
	
	return hook,""
}
