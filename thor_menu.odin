package main

import sdl "vendor:sdl3"
import "core:fmt"
import "base:runtime"
import "core:sys/windows"

config: struct{

}

wproc :: proc "system"(
    hwnd: windows.HWND,
    uMsg: windows.UINT,
    wParam: windows.WPARAM,
    lParam: windows.LPARAM)->windows.LRESULT{
        
        return windows.DefWindowProcW(
            hwnd,
            uMsg,
            wParam,
            lParam
        )
    }

menu: struct{
    HWND: ^windows.HWND
}


window_init :: proc "system" (){
    mnu := &menu

    hinstance := windows.GetModuleHandleW(nil)

    classname : windows.LPCWSTR = "Thor Start"

    wc := windows.WNDCLASSW{}
    wc.lpfnWndProc = wproc
    wc.hInstance = cast(windows.HINSTANCE)hinstance
    wc.lpszClassName = classname


}