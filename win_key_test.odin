package main

import "core:testing"
import windows "core:sys/windows"

// Proves repeated solo Win presses toggle privately without ever gifting Windows half a key press.
@(test)
standalone_win_key_stays_balanced_across_repeated_toggles :: proc(t: ^testing.T) {
	state: Win_Key_State

	for _ in 0 ..< 3 {
		testing.expect_value(
			t,
			track_key_event(&state, u32(windows.VK_LWIN), true),
			Key_Hook_Action.Suppress,
		)
		testing.expect_value(
			t,
			track_key_event(&state, u32(windows.VK_LWIN), false),
			Key_Hook_Action.Toggle_Menu,
		)
		testing.expect_value(t, state.win_keys_down, 0)
		testing.expect_value(t, state.standalone_candidate, false)
		testing.expect_value(
			t,
			state.win_down_forwarded[int(windows.VK_LWIN)],
			false,
		)
	}
}

// Confirms a second key promotes the withheld Win-down into a complete shortcut chord.
@(test)
win_shortcut_forwards_balanced_down_and_up_events :: proc(t: ^testing.T) {
	state: Win_Key_State
	win_key := u32(windows.VK_LWIN)
	shortcut_key := u32('D')

	testing.expect_value(
		t,
		track_key_event(&state, win_key, true),
		Key_Hook_Action.Suppress,
	)
	testing.expect_value(
		t,
		track_key_event(&state, shortcut_key, true),
		Key_Hook_Action.Begin_Shortcut,
	)
	finish_shortcut_forwarding(&state, shortcut_key, 2)

	testing.expect_value(
		t,
		track_key_event(&state, shortcut_key, false),
		Key_Hook_Action.Forward,
	)
	testing.expect_value(
		t,
		track_key_event(&state, win_key, false),
		Key_Hook_Action.Forward,
	)
	testing.expect_value(t, state.win_keys_down, 0)
	testing.expect_value(t, state.non_win_keys_down, 0)
}

// Keeps a failed SendInput attempt safe by suppressing the Win-up Windows never earned.
@(test)
failed_shortcut_forwarding_cannot_stick_win_key :: proc(t: ^testing.T) {
	state: Win_Key_State
	win_key := u32(windows.VK_LWIN)
	shortcut_key := u32('D')

	testing.expect_value(
		t,
		track_key_event(&state, win_key, true),
		Key_Hook_Action.Suppress,
	)
	testing.expect_value(
		t,
		track_key_event(&state, shortcut_key, true),
		Key_Hook_Action.Begin_Shortcut,
	)
	finish_shortcut_forwarding(&state, shortcut_key, 0)

	testing.expect_value(
		t,
		track_key_event(&state, shortcut_key, false),
		Key_Hook_Action.Forward,
	)
	testing.expect_value(
		t,
		track_key_event(&state, win_key, false),
		Key_Hook_Action.Suppress,
	)
}

// Ensures Win pressed during an existing key hold passes through normally and never toggles Thor.
@(test)
win_pressed_after_another_key_is_not_standalone :: proc(t: ^testing.T) {
	state: Win_Key_State
	win_key := u32(windows.VK_LWIN)
	other_key := u32('D')

	testing.expect_value(
		t,
		track_key_event(&state, other_key, true),
		Key_Hook_Action.Forward,
	)
	testing.expect_value(
		t,
		track_key_event(&state, win_key, true),
		Key_Hook_Action.Forward,
	)
	testing.expect_value(
		t,
		track_key_event(&state, win_key, false),
		Key_Hook_Action.Forward,
	)
	testing.expect_value(
		t,
		track_key_event(&state, other_key, false),
		Key_Hook_Action.Forward,
	)
}
