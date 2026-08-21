package main

import "vendor:directx/dxgi"
import sdl "vendor:sdl3"
import "core:fmt"
import "base:runtime"
import "core:sys/windows"
import d3d "vendor:directx/d3d11"

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

device_flags : d3d.CREATE_DEVICE_FLAGS ={
    .BGRA_SUPPORT
}

mode_desc : dxgi.MODE_DESC = {
    Width = 0,
    Height = 0,
    RefreshRate= dxgi.RATIONAL{
        Numerator= 0,
        Denominator = 0
    },
    Format = dxgi.FORMAT.B8G8R8A8_UNORM,
    ScanlineOrdering = dxgi.MODE_SCANLINE_ORDER.UNSPECIFIED,
    Scaling = dxgi.MODE_SCALING.UNSPECIFIED
}

swap_mode_desc : dxgi.SWAP_CHAIN_DESC ={
    BufferDesc = mode_desc,
    SampleDesc = dxgi.SAMPLE_DESC{
        Count = 1,
        Quality = 0
    },
    BufferUsage = dxgi.USAGE{
        .RENDER_TARGET_OUTPUT
    },
    BufferCount = 2,
    
}

window_init :: proc "stdcall" (){
    mnu := &menu

    hinstance := windows.GetModuleHandleW(nil)

    classname : windows.LPCWSTR = "Thor Start"

    wc := windows.WNDCLASSW{}
    wc.lpfnWndProc = wproc
    wc.hInstance = cast(windows.HINSTANCE)hinstance
    wc.lpszClassName = classname

    dswap := d3d.CreateDeviceAndSwapChain(
        nil,
        d3d.DRIVER_TYPE.HARDWARE,
        nil,
        device_flags,
        nil,
        6,
        d3d.SDK_VERSION,
        &swap_mode_desc
    )
}