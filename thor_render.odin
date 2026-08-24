package main

import "vendor:directx/dxgi"
import "core:fmt"
import "base:runtime"
import "core:sys/windows"
import d3d "vendor:directx/d3d11"

Config:: struct{
    width: f32,
    height: f32
}

Window::struct{
    hwnd: windows.HWND,
    swap_chain: ^dxgi.ISwapChain,
    device: ^d3d.IDevice,
    ctx: ^d3d.IDeviceContext,
    backbuffer: ^d3d.ITexture2D,
    render_target: ^d3d.IRenderTargetView,
    viewport: d3d.VIEWPORT,
    buffer: ^d3d.IBuffer,
    input_layout: ^d3d.IInputLayout
}

Menu:: struct{
    config: Config,
    window: Window
}



wproc :: proc "system"(
    hwnd: windows.HWND,
    uMsg: windows.UINT,
    wParam: windows.WPARAM,
    lParam: windows.LPARAM)->windows.LRESULT{
        switch uMsg{
            case windows.WM_CLOSE:
                windows.DestroyWindow(hwnd)
                windows.UnregisterClassW(
                    "Thor Start",
                    hinstance
                )
                return 0
            case windows.WM_DESTROY:
                windows.PostQuitMessage(0)
                break;
        }

        return windows.DefWindowProcW(
            hwnd,
            uMsg,
            wParam,
            lParam
        )
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

hinstance: windows.HINSTANCE

window_init :: proc "stdcall" ()->Menu{
    context = runtime.default_context()

    menu := Menu{}
    menu.config = Config{
        width= 600,
        height = 800
    }
    hinstance = cast(windows.HINSTANCE)windows.GetModuleHandleW(nil)

    classname : windows.LPCWSTR = "Thor Start"

    wc := windows.WNDCLASSW{}
    wc.lpfnWndProc = wproc
    wc.hInstance = cast(windows.HINSTANCE)hinstance
    wc.lpszClassName = classname
    windows.RegisterClassW(&wc)

    hwnd := windows.CreateWindowExW(
        windows.WS_EX_TOOLWINDOW |windows.WS_EX_TOPMOST,
        classname,
        "ThorStart",
        windows.WS_VISIBLE| windows.WS_POPUP,
        windows.CW_USEDEFAULT,
        windows.CW_USEDEFAULT,
        cast(i32)menu.config.width,
        cast(i32)menu.config.height,
        nil,
        nil,
        hinstance,
        nil
    )

    menu.window.hwnd = hwnd
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
    OutputWindow = hwnd,
    Windowed = true,
    SwapEffect = dxgi.SWAP_EFFECT.FLIP_DISCARD,

    }

    hr := d3d.CreateDeviceAndSwapChain(
        nil,
        d3d.DRIVER_TYPE.HARDWARE,
        nil,
        device_flags,
        nil,
        0,
        d3d.SDK_VERSION,
        &swap_mode_desc,
        &menu.window.swap_chain,
        &menu.window.device,
        nil,
        &menu.window.ctx
    )
    
    if windows.FAILED(hr) {
        fmt.printfln("Create device and swap chain failed: 0x%08X\n", hr)
        return Menu{}
    }

    hr = menu.window.swap_chain.GetBuffer(
        menu.window.swap_chain,
        0,
        d3d.ITexture2D_UUID,
        cast(^rawptr)&menu.window.backbuffer
    )

    if windows.FAILED(hr){
        fmt.printfln("Create windows back buffer failed: 0x%08X\n", hr)
        return Menu{}
    }

    hr = menu.window.device.CreateRenderTargetView(
        menu.window.device,
        cast(^d3d.IResource)menu.window.backbuffer,
        nil,
        &menu.window.render_target
    )

    if windows.FAILED(hr){
        fmt.printfln("Create render target failed: 0x%08X\n", hr)
        return Menu{}
    }

    menu.window.ctx.OMSetRenderTargets(
        menu.window.ctx,
        1,
        cast([^]^d3d.IRenderTargetView)&menu.window.render_target,
        nil
    )

    menu.window.viewport = d3d.VIEWPORT{
        Width = menu.config.width,
        Height = menu.config.height,
        MinDepth = 0,
        MaxDepth = 1,
        TopLeftX = 200,
        TopLeftY = 200,
    }

    menu.window.ctx.RSSetViewports(
        menu.window.ctx,
        1,
        cast([^]d3d.VIEWPORT)&menu.window.viewport
    )
    windows.ShowWindow(hwnd,1)
    return menu
}

clear_color := [4]f32{0.08,0.08,0.08,1}


render_frame :: proc "system"(menu: Menu){
    menu.window.ctx.ClearRenderTargetView(
        menu.window.ctx,
        menu.window.render_target,
        &clear_color
    )
    menu.window.swap_chain.Present(
        menu.window.swap_chain,
        0,
        dxgi.PRESENT{ }
    )
}

Vertex :: struct {
    position: [3]f32,
    color: [4]f32,
}


init_buffer :: proc "stdcall"(menu:^Menu)->bool{

    context = runtime.default_context()

    testRect := [6]Vertex{
    {
        position= {0,0,1},
        color = {1,0,0,1}
    },
    {
        position= {0,50,1},
        color = {1,0,0,1}
    },
    {
        position = {50,0,1},
        color = {1,0,0,1}
    },
    {
        position= {50,50,1},
        color = {1,0,0,1}
    },
    {
        position= {0,50,1},
        color = {1,0,0,1}
    },
    {
        position = {50,0,1},
        color = {1,0,0,1}
    }
}

    buffer_desc := d3d.BUFFER_DESC{
        Usage = d3d.USAGE.DEFAULT,
        ByteWidth =  u32(size_of(testRect)),
        BindFlags = d3d.BIND_FLAGS{.VERTEX_BUFFER},
        CPUAccessFlags = d3d.CPU_ACCESS_FLAGS{},
        MiscFlags = d3d.RESOURCE_MISC_FLAGS{},
    }

    Init_data : d3d.SUBRESOURCE_DATA = {
        pSysMem = &testRect[0],
        SysMemPitch = 0,
        SysMemSlicePitch = 0
    }

    hr := menu.window.device.CreateBuffer(
        menu.window.device,
        &buffer_desc,
        &Init_data,
        &menu.window.buffer,
    )

    
    if windows.FAILED(hr){
        fmt.printfln("buffer creation failed: 0x%08X", hr)
        return false
    }
    return true
}

ui_vertext := #load("./ui_vertex.cso")

init_layout_desc :: proc "system"(menu:^Menu){
    desc := &[]d3d.INPUT_ELEMENT_DESC{
        {
            SemanticName = "POSTITION",
            SemanticIndex = 0,
            Format = dxgi.FORMAT.R32G32B32A32_FLOAT,
            InputSlot = 0,
            InputSlotClass = .VERTEX_DATA,
            InstanceDataStepRate = 0
        },
        {
            SemanticName = "COLOR",
            SemanticIndex = 0,
            Format = dxgi.FORMAT.R32G32B32A32_FLOAT,
            InputSlot = 0,
            InputSlotClass = .VERTEX_DATA,
            InstanceDataStepRate = 0
        }
    }

    hr := menu.window.device.CreateInputLayout(
        menu.window.device,
        raw_data(desc[:]),
        size_of(desc),
        &ui_vertext,
        size_of(ui_vertext),
        &menu.window.input_layout
    )
}