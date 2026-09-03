# Thor Start

Thor Start is an experimental Windows Start-menu replacement written in
[Odin](https://odin-lang.org/). It uses Win32 for shell integration and window
management, and Direct3D 11 for rendering.

The project is under active development. It currently creates the launcher
window, lays out colored UI nodes, discovers Start Menu shortcuts, extracts
their Windows icons, and converts those icons into D3D11 shader-resource views.

## Requirements

- Windows 10 or Windows 11
- The Odin compiler available as `odin`
- A Direct3D 11-capable GPU
- The Windows SDK shader compiler (`fxc.exe`) when changing HLSL shaders

## Build and run

```powershell
odin build . -debug -out:thor-start.exe
.\thor-start.exe
```

In Visual Studio Code, the included **Build Thor Debug** task performs the same
debug build.

Run the layout tests with a separate output name so they do not conflict with a
running launcher:

```powershell
odin test . -debug -out:layout-tests.exe
```

## Project structure

- `main.odin` — application startup and high-level initialization
- `thor_render.odin` — Win32 window and Direct3D 11 renderer setup
- `render_api.odin` — node layout and rectangle geometry generation
- `nodes.odin` — UI tree, sizing modes, colors, and layout configuration
- `layout_test.odin` — row and column wrapping tests
- `app_discover.odin` — Start Menu shortcut and shell-icon discovery
- `winicon.odin` — taskbar Start-button discovery and Thor icon overlay
- `winkey.odin` — Windows-key hook and Win32 message loop
- `hlsl/defshader.hlsl` — UI vertex and pixel shader source

## Layout

A container controls how its direct children are placed:

```odin
root.layout.direction = .Row    // or .Column
root.layout.wrap = true
root.layout.gap = 8
root.layout.padding = {left = 12, top = 8, right = 12, bottom = 8}
add_border(&root, Border{
    color = color_red,
    sides = {top = 1, bottom = 2, left = 0, right = 4},
})
```

Children support `.Pixels`, `.Percent`, `.Flex`, and `.Auto` sizing.
Row layouts advance horizontally and wrap into additional rows. Column layouts
advance vertically and wrap into additional columns. Layout is applied
recursively to nested containers.

## Recompiling shaders

The application loads `ui_vertex.cso` and `ui_pixel.cso` at compile time.
After editing `hlsl/defshader.hlsl`, rebuild the bytecode:

```powershell
fxc /nologo /T vs_5_0 /E RenderV /Fo ui_vertex.cso hlsl\defshader.hlsl
fxc /nologo /T ps_5_0 /E RenderP /Fo ui_pixel.cso hlsl\defshader.hlsl
```

The HLSL source also contains a `RenderIcon` entry point for the developing
textured-icon pass.

## Icon resources

`get_start_apps` finds common Start Menu `.lnk` files with
`SHGetFileInfoW`. `icon_to_texture` draws each returned `HICON` into a
32×32 BGRA bitmap and uploads it as a D3D11 shader-resource view.

Resource ownership is explicit:

- The caller must destroy each shell `HICON` after conversion.
- The caller owns every returned shader-resource view and must call
  `Release` when it is no longer needed.
- The caller owns the dynamic array returned by `get_start_apps`.

## Current limitations

- Textured icons are discovered and uploaded, but are not yet connected to UI
  nodes or sampled by the active render pass.
- Only the shared Start Menu directory under `C:/ProgramData` is scanned.
- The scene is built and presented once before entering the message loop;
  continuous redraw and resize handling are not implemented yet.
- Application entry and GPU-resource cleanup still needs to be wired into the
  launcher lifetime.
