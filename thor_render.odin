package main


import "vendor:directx/dxgi"
import "core:fmt"
import "core:mem"
import "base:runtime"
import "core:sys/windows"
import d3d "vendor:directx/d3d11"


Config:: struct{
    width: f32,
    height: f32
}

Frame_Data :: struct {
    viewport_size : [2]f32,
    padding : [2]f32
}

Window::struct{
    hwnd: windows.HWND,
    swap_chain: ^dxgi.ISwapChain,
    device: ^d3d.IDevice,
    ctx: ^d3d.IDeviceContext,
    backbuffer: ^d3d.ITexture2D,
    render_target: ^d3d.IRenderTargetView,
    viewport: d3d.VIEWPORT,
    vertex_renderer: struct {
            frame_buffer : ^d3d.IBuffer,
            vertex_buffer: ^d3d.IBuffer,
            vertex_capacity: int,
            vertices: [dynamic]Vertex,
        },
    input_layout: ^d3d.IInputLayout,
    vertex_shader : ^d3d.IVertexShader,
    pixel_shader : ^d3d.IPixelShader,
    icon_pixel_shader : ^d3d.IPixelShader,
    icon_sampler : ^d3d.ISamplerState,
    frame_data : Frame_Data,
    blend_state : ^d3d.IBlendState,
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
    .BGRA_SUPPORT,
    .DEBUG
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
        TopLeftX = 0,
        TopLeftY = 0,
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




Vertex :: struct {
    position: [3]f32,
    color: [4]f32,
    uv : [2]f32,
}


init_buffer :: proc "stdcall"(menu:^Menu)->bool{

    context = runtime.default_context()

    
    menu.window.vertex_renderer.vertex_capacity = 4800
    buffer_desc := d3d.BUFFER_DESC{
        Usage = d3d.USAGE.DYNAMIC,
        ByteWidth =  cast(u32)(menu.window.vertex_renderer.vertex_capacity * size_of(Vertex)),
        BindFlags = d3d.BIND_FLAGS{.VERTEX_BUFFER},
        CPUAccessFlags = d3d.CPU_ACCESS_FLAGS{.WRITE},
        MiscFlags = d3d.RESOURCE_MISC_FLAGS{},
    }

    

    buffer : ^d3d.IBuffer
    hr := menu.window.device.CreateBuffer(
        menu.window.device,
        &buffer_desc,
        nil,
        &menu.window.vertex_renderer.vertex_buffer,
    )

    
    if windows.FAILED(hr){
        fmt.printfln("buffer creation failed: 0x%08X", hr)
        return false
    }

    return true
}

ui_vertex := #load("./ui_vertex.cso")
ui_pixel := #load("./ui_pixel.cso")
icon_pixel := #load("./icon_pixel.cso")
init_set_layout_and_buffer :: proc "stdcall"(menu:^Menu)->bool{
    context = runtime.default_context()

    desc := [3]d3d.INPUT_ELEMENT_DESC{
        {
            SemanticName = "POSITION",
            SemanticIndex = 0,
            Format = dxgi.FORMAT.R32G32B32_FLOAT,
            InputSlot = 0,
            InputSlotClass = .VERTEX_DATA,
            InstanceDataStepRate = 0,
            AlignedByteOffset =0,
        },
        {
            SemanticName = "COLOR",
            SemanticIndex = 0,
            Format = dxgi.FORMAT.R32G32B32A32_FLOAT,
            InputSlot = 0,
            InputSlotClass = .VERTEX_DATA,
            InstanceDataStepRate = 0,
            AlignedByteOffset = 12,
        },
        {
            SemanticName = "TEXCOORD",
            SemanticIndex = 0,
            Format = dxgi.FORMAT.R32G32_FLOAT,
            InputSlot = 0,
            InputSlotClass = .VERTEX_DATA,
            AlignedByteOffset = 28,
        }
    }

    hr := menu.window.device.CreateInputLayout(
        menu.window.device,
        raw_data(desc[:]),
        len(desc),
        raw_data(ui_vertex),
        len(ui_vertex),
        &menu.window.input_layout
    )
    if windows.FAILED(hr) {
        fmt.printfln("CreateInputLayout failed: 0x%08X", hr)
        return false
    }

    stride :u32= u32(size_of(Vertex))
    offset :u32= 0
    menu.window.ctx.IASetVertexBuffers(
        menu.window.ctx,
        0,
        1,
        &menu.window.vertex_renderer.vertex_buffer,
        cast([^]u32)&stride,
        cast([^]u32)&offset,
    )

    menu.window.ctx.IASetInputLayout(
        menu.window.ctx,
        menu.window.input_layout,
    )

    menu.window.ctx.IASetPrimitiveTopology(
        menu.window.ctx,
        .TRIANGLELIST,
    )

   hr = menu.window.device.CreateVertexShader(
        menu.window.device,
        raw_data(ui_vertex),
        len(ui_vertex),
        nil,
        &menu.window.vertex_shader,
    )

    if windows.FAILED(hr) {
        fmt.printfln("CreateVertexShader failed: 0x%08X", hr)
        return false
    }

    menu.window.ctx.VSSetShader(
        menu.window.ctx,
        menu.window.vertex_shader,
        nil,
        0
    )

    hr = menu.window.device.CreatePixelShader(
        menu.window.device,
        raw_data(ui_pixel),
        len(ui_pixel),
        nil,
        &menu.window.pixel_shader,
    )
    if windows.FAILED(hr) {
        fmt.printfln("CreatePixelShader failed: 0x%08X", hr)
        return false
    }

    menu.window.ctx.PSSetShader(
        menu.window.ctx,
        menu.window.pixel_shader,
        nil,
        0
    )

    raster_desc := d3d.RASTERIZER_DESC{
    FillMode              = .SOLID,
    CullMode              = .NONE,
    FrontCounterClockwise = false,
    DepthClipEnable       = true,
    }

    raster_state: ^d3d.IRasterizerState

    hr = menu.window.device.CreateRasterizerState(
        menu.window.device,
        &raster_desc,
        &raster_state,
    )

    if windows.FAILED(hr) {
        fmt.printfln("CreateRasterizerState failed: 0x%08X", hr)
        return false
    }

    menu.window.ctx.RSSetState(
        menu.window.ctx,
        raster_state,
    )

    frame_buffer_desc := d3d.BUFFER_DESC{
    Usage          = .DYNAMIC,
    ByteWidth      = u32(size_of(Frame_Data)),
    BindFlags      = {.CONSTANT_BUFFER},
    CPUAccessFlags = {.WRITE},
    }

    menu.window.frame_data = Frame_Data{
        viewport_size = {
            menu.config.width,
            menu.config.height,
        },
    }

    init_data := d3d.SUBRESOURCE_DATA{
        pSysMem = &menu.window.frame_data,
    }

    hr = menu.window.device.CreateBuffer(
        menu.window.device,
        &frame_buffer_desc,
        &init_data,
        &menu.window.vertex_renderer.frame_buffer,
    )
    
    menu.window.ctx.VSSetConstantBuffers(
        menu.window.ctx,
        0,
        1,
        cast([^]^d3d.IBuffer)&menu.window.vertex_renderer.frame_buffer,   
    )

    sampler_desc := d3d.SAMPLER_DESC{
        Filter = .MIN_MAG_MIP_LINEAR,
        AddressU = .CLAMP,
        AddressV = .CLAMP,
        AddressW = .CLAMP,
    }

    hr = menu.window.device.CreateSamplerState(
        menu.window.device,
        &sampler_desc,
        &menu.window.icon_sampler,
    )

    if windows.FAILED(hr) {
        fmt.printfln(
            "CreateSamplerState failed: 0x%08X",
            cast(u32)hr,
        )
        return false
    }
    menu.window.ctx.PSSetSamplers(
        menu.window.ctx,
        0,
        1,
        &menu.window.icon_sampler,
    )

    blend_desc := d3d.BLEND_DESC{}

    blend_desc.RenderTarget[0] = d3d.RENDER_TARGET_BLEND_DESC{
        BlendEnable           = true,

        SrcBlend              = .SRC_ALPHA,
        DestBlend             = .INV_SRC_ALPHA,
        BlendOp               = .ADD,

        SrcBlendAlpha         = .ONE,
        DestBlendAlpha        = .INV_SRC_ALPHA,
        BlendOpAlpha          = .ADD,

        RenderTargetWriteMask = 0x0f,
    }

    hr = menu.window.device.CreateBlendState(
        menu.window.device,
        &blend_desc,
        &menu.window.blend_state,
    )

    if windows.FAILED(hr) {
        fmt.printfln(
            "CreateBlendState failed: 0x%08X",
            cast(u32)hr,
        )
        return false
    }

    menu.window.ctx.OMSetBlendState(
        menu.window.ctx,
        menu.window.blend_state,
        nil,
        0xffffffff,
    )


    return true


}

build_frame :: proc "system" (menu: ^Menu)->bool{

    context = runtime.default_context()

    mapped_resource : d3d.MAPPED_SUBRESOURCE

    vertex_count := len(menu.window.vertex_renderer.vertices)

    if vertex_count == 0 {
        return true
    }

    if vertex_count > menu.window.vertex_renderer.vertex_capacity {
        fmt.println("vertex buffer capacity exceeded")
        return false
    }

    hr := menu.window.ctx.Map(
            menu.window.ctx,
            menu.window.vertex_renderer.vertex_buffer,
            0,
            d3d.MAP.WRITE_DISCARD,
            {},
            &mapped_resource
        )
    
    if windows.FAILED(hr) {
        fmt.printfln("BufferMap failed: 0x%08X", hr)
        return false
    }

    vert_ptr := cast([^]Vertex)mapped_resource.pData

    dst := vert_ptr[:len(menu.window.vertex_renderer.vertices)]
    copy(
        dst,

        menu.window.vertex_renderer.vertices[:]
    )

    menu.window.ctx.Unmap(
        menu.window.ctx,
        menu.window.vertex_renderer.vertex_buffer,
    0)
    

    return true
}

push_frame :: proc (menu:^Menu){
    menu.window.ctx.ClearRenderTargetView(
        menu.window.ctx,
        menu.window.render_target,
        &clear_color,
    )

    menu.window.ctx.Draw(
        menu.window.ctx,
        u32(len(menu.window.vertex_renderer.vertices)),
        0,
    )

    menu.window.swap_chain.Present(
        menu.window.swap_chain,
        0,
    {}
    )

}

// The caller retains ownership of icon and owns the returned SRV reference.
icon_to_texture :: proc "system" (
    icon: windows.HICON,
    menu: ^Menu,
) -> ^d3d.IShaderResourceView {
    context = runtime.default_context()

    if icon == nil || menu == nil || menu.window.device == nil {
        return nil
    }

    icon_info := windows.ICONINFOEXW{
        cbSize = u32(size_of(windows.ICONINFOEXW)),
    }
    if !windows.GetIconInfoExW(icon, &icon_info) {
        fmt.printfln(
            "GetIconInfoExW failed: %d",
            windows.GetLastError(),
        )
        return nil
    }
    defer {
        if icon_info.hbmColor != nil {
            windows.DeleteObject(cast(windows.HGDIOBJ)icon_info.hbmColor)
        }
        if icon_info.hbmMask != nil {
            windows.DeleteObject(cast(windows.HGDIOBJ)icon_info.hbmMask)
        }
    }

    screen_dc := windows.GetDC(nil)
    if screen_dc == nil {
        fmt.printfln("GetDC failed: %d", windows.GetLastError())
        return nil
    }
    defer windows.ReleaseDC(nil, screen_dc)

    memory_dc := windows.CreateCompatibleDC(screen_dc)
    if memory_dc == nil {
        fmt.printfln(
            "CreateCompatibleDC failed: %d",
            windows.GetLastError(),
        )
        return nil
    }
    defer windows.DeleteDC(memory_dc)

    // Negative height creates a top-down BGRA bitmap, matching texture row order.
    bmi := windows.BITMAPINFO{
        bmiHeader = {
            biSize = size_of(windows.BITMAPINFOHEADER),
            biWidth = 32,
            biHeight = -32,
            biPlanes = 1,
            biBitCount = 32,
            biCompression = windows.BI_RGB,
        },
    }

    pixels_raw: rawptr
    bitmap := windows.CreateDIBSection(
        screen_dc,
        &bmi,
        windows.DIB_RGB_COLORS,
        &pixels_raw,
        nil,
        0,
    )
    if bitmap == nil || pixels_raw == nil {
        fmt.printfln(
            "CreateDIBSection failed: %d",
            windows.GetLastError(),
        )
        return nil
    }
    defer windows.DeleteObject(cast(windows.HGDIOBJ)bitmap)

    old_bitmap := windows.SelectObject(
        memory_dc,
        cast(windows.HGDIOBJ)bitmap,
    )
    if old_bitmap == nil {
        fmt.printfln("SelectObject failed: %d", windows.GetLastError())
        return nil
    }
    defer windows.SelectObject(memory_dc, old_bitmap)

    pixels := cast([^]u8)pixels_raw
    mem.zero_slice(pixels[:32 * 32 * 4])

    if !windows.DrawIcon(memory_dc, 0, 0, icon) {
        fmt.printfln("DrawIcon failed: %d", windows.GetLastError())
        return nil
    }

    texture_desc := d3d.TEXTURE2D_DESC{
        Width = 32,
        Height = 32,
        MipLevels = 1,
        ArraySize = 1,
        Format = .B8G8R8A8_UNORM,
        SampleDesc = {
            Count = 1,
            Quality = 0,
        },
        Usage = .DEFAULT,
        BindFlags = {.SHADER_RESOURCE},
    }
    initial_data := d3d.SUBRESOURCE_DATA{
        pSysMem = pixels_raw,
        SysMemPitch = 32 * 4,
        SysMemSlicePitch = 32 * 32 * 4,
    }

    texture: ^d3d.ITexture2D
    hr := menu.window.device.CreateTexture2D(
        menu.window.device,
        &texture_desc,
        &initial_data,
        &texture,
    )
    if windows.FAILED(hr) {
        fmt.printfln("CreateTexture2D failed: 0x%08X", cast(u32)hr)
        return nil
    }
    defer texture.Release(cast(^windows.IUnknown)texture)

    texture_view: ^d3d.IShaderResourceView
    hr = menu.window.device.CreateShaderResourceView(
        menu.window.device,
        cast(^d3d.IResource)texture,
        nil,
        &texture_view,
    )
    if windows.FAILED(hr) {
        fmt.printfln(
            "CreateShaderResourceView failed: 0x%08X",
            cast(u32)hr,
        )
        return nil
    }

    
    return texture_view
}

