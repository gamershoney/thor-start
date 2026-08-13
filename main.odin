package main

import "core:fmt"
import windows "core:sys/windows"

keyboard_proc :: proc "stdcall"(
    nCode: i32,
    wParam: windows.WPARAM,
    lParam: windows.LPARAM
){}

hmod := windows.GetModuleHandleW(nil)
bindWinKey :: proc(){
    windows.SetWindowsHookExW(windows.WH_KEYBOARD_LL,keyboard_proc,windows.GetModuleHandleW(nil),0)
}

main :: proc() {

}