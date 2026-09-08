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

The Thor icon, Inter Medium font, and compiled shader bytecode are embedded
into the executable at compile time. They do not need to be distributed as
loose runtime files.

Inter is distributed under the SIL Open Font License 1.1. Keep
`fonts/Inter-LICENSE.txt` with source or binary distributions unless the
license is made available through the application itself.

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

## Configuration

Thor Start reads `%LOCALAPPDATA%\Thor-Start\config.json`. If the file does not
exist, the application creates it from `default_config`. Existing JSON is
layered over those defaults, so omitted settings retain their default values.
If the file cannot be read or parsed, Thor Start continues with the complete
default configuration.

`app_list_font_size` controls the app-list text size in pixels.

## Project structure

- `main.odin` — application startup and high-level initialization
- `config.odin` — JSON discovery, defaults, loading, and first-run creation
- `thor_render.odin` — Win32 window and Direct3D 11 renderer setup
- `render_api.odin` — node layout and rectangle geometry generation
- `nodes.odin` — UI tree, sizing modes, colors, and layout configuration
- `layout_test.odin` — row and column wrapping tests
- `app_discover.odin` — Start Menu shortcut and shell-icon discovery
- `win_icon.odin` — taskbar Start-button discovery and Thor icon overlay
- `win_key.odin` — Windows-key hook and Win32 message loop
- `hlsl/defshader.hlsl` — UI vertex and pixel shader source
- `fonts/Inter-Medium.ttf` — embedded UI font source
- `fonts/Inter-LICENSE.txt` — Inter’s SIL Open Font License

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

The application embeds all four `.cso` files at compile time. After editing
`hlsl/defshader.hlsl`, rebuild the bytecode with:

```powershell
.\recompile-shaders.ps1
```

## Icon resources

`cache_start_apps` finds common Start Menu `.lnk` files once with
`SHGetFileInfoW`. `icon_to_texture` draws each returned `HICON` into a
BGRA bitmap and uploads it as a D3D11 shader-resource view. App-list nodes
retain cache keys rather than owning duplicate app records.

Resource ownership is explicit:

- The caller must destroy each shell `HICON` after conversion.
- The caller owns every returned shader-resource view and must call
  `Release` when it is no longer needed.
- `destroy_start_app_cache` releases the cached strings, map storage, and GPU
  icon resources at shutdown.

## Current limitations

- Only the shared Start Menu directory under `C:/ProgramData` is scanned.
- Taskbar integration depends on Explorer exposing the Start button through
  Windows UI Automation with the `StartButton` automation ID.
