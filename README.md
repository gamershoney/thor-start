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
New-Item -ItemType Directory -Force build | Out-Null
odin build . -debug -out:build\thor-start-debug.exe
.\build\thor-start-debug.exe
```

In Visual Studio Code, the included **Build Thor Debug** task performs the same
debug build.

Run the layout tests with a separate output name so they do not conflict with a
running launcher:

```powershell
odin test . -debug -out:build\thor-start-tests.exe
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
- `tray_icon.odin` — notification-area icon, restart, and exit controls
- `win_key.odin` — Windows-key hook and Win32 message loop
- `hlsl/defshader.hlsl` — UI vertex and pixel shader source
- `fonts/Inter-Medium.ttf` — embedded UI font source
- `fonts/Inter-LICENSE.txt` — Inter’s SIL Open Font License

## Layout

### Theme customization

The top bar's **Edit config** button opens the same JSON file used at startup
in Notepad. Save your changes and restart Thor Start to apply them.
Its appearance is configurable through `top_bar_background_color`,
`top_bar_text_color`, `top_bar_border`, `top_bar_font_size`,
`config_button_highlighting`, and `config_button_text_color`.

The default slate/ice palette is declared in `colors.odin` and assigned to UI
roles in `default_config` in `config.odin`. The loaded JSON config remains the
source of truth: colors are normalized RGBA arrays (`[r, g, b, a]`, each 0–1).
Customize `background_color`, `app_list_highlighting`, `app_list_text_color`,
`app_list_border`, `search_bar_background_color`, `search_bar_text_color`,
and `search_bar_border`. Borders contain `color` and `sides` (top, bottom,
left, right in pixels; zero disables a side).

Existing config files are not overwritten. Missing fields use the new defaults,
but previously saved colors still override them. To adopt the new palette,
remove the old color overrides from your JSON, or back up the config and remove
it to regenerate all defaults on the next launch. Restart after editing.

`app_refresh_interval_seconds` controls how often Thor rescans shortcuts when
the menu opens (default: 300 seconds). Set it to 0 to disable automatic refresh.
Diagnostics are appended to `%LOCALAPPDATA%\Thor-Start\thor-start.log`.

Thor also adds a notification-area icon. Right-click it to open, restart, or
exit Thor Start; double-clicking toggles the launcher. Windows may initially
place this icon in the hidden-icons overflow panel. The icon restores itself
after Explorer restarts.

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

`cache_start_apps` scans both the current-user and all-users Start Menu
locations. Same-named shortcuts are deduplicated case-insensitively, with the
current-user shortcut taking precedence. It uses
`SHGetFileInfoW`. `icon_to_texture` draws each returned `HICON` into a
BGRA bitmap and uploads it as a D3D11 shader-resource view. App-list nodes
retain cache keys rather than owning duplicate app records.

Resource ownership is explicit:

- The caller must destroy each shell `HICON` after conversion.
- The caller owns every returned shader-resource view and must call
  `Release` when it is no longer needed.
- `destroy_start_app_cache` releases the cached strings, map storage, and GPU
  icon resources at shutdown.

## Searching apps

Press the Windows key and type immediately to filter cached app names
(case-insensitive); the launcher takes keyboard focus as it opens.
Up/Down selects a result and keeps it in view; Enter launches it. Click a
result to launch with the mouse. Escape clears a query, then closes the menu
when the query is empty.

The search field supports Unicode typing, Backspace/Delete, Left/Right,
Home/End, and Ctrl+V paste. A vertical bar marks the insertion point.
Queries are limited to 1024 UTF-8 bytes. Search currently targets cached
Start Menu apps, not files or web results.

## Current limitations

- Search covers Start Menu shortcuts, not packaged apps without shortcuts,
  arbitrary files, settings, or web results.
- The taskbar overlay depends on Explorer exposing `StartButton` through UI
  Automation. If it does not, Thor logs a warning and remains usable through
  the Windows-key shortcut. If Explorer restarts after a successful startup,
  the overlay reacquires the replacement taskbar and Start-button element.

## Release packaging

`build-release.ps1` starts from a clean temporary staging directory, runs the
tests, creates a 256-pixel Windows icon, compiles the Per-Monitor-V2 manifest
and version metadata, builds an optimized GUI executable, includes the Inter
license, and writes a versioned ZIP under `dist/`:

```powershell
.\build-release.ps1
```

The EXE is self-contained. The script verifies that the finished ZIP contains
exactly `thor-start.exe`, `README.md`, and `Inter-LICENSE.txt`, then removes its
temporary staging directory.

## Windows beta test matrix

Automated placement tests cover bottom, top, left, and right taskbars on an
offset secondary-monitor coordinate space, including menu dimensions
representative of 100%, 125%, and 150% scaling. Before publishing a beta,
manually exercise those three scale settings, primary and secondary taskbars,
auto-hide, and an Explorer restart. Verify that the overlay reacquires the
Start button, the menu opens inward from the taskbar, wheel scrolling hits the
row beneath the pointer, hover clears on exit, and focus loss closes the menu.
