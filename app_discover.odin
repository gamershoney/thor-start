package main

import "base:runtime"
import "core:os"
import "core:fmt"
import "core:strings"
import "core:sys/windows"
import "core:time"
import "core:log"
foreign import Shell32 "system:shell32.lib"
import d3d "vendor:directx/d3d11"


// Carries Shell secrets across the Win32 wilderness like a tiny, overqualified backpack.
SHFILEINFOW :: struct {
    hIcon : windows.HICON,
    iIcon : int,
    dwAttributes: windows.DWORD,
    szDisplayName : [windows.MAX_PATH]windows.WCHAR,
    szTypeName : [80]windows.WCHAR,
}

foreign Shell32 {
    SHGetFileInfoW :: proc "system" (
        pszPath: windows.LPCTSTR,
        dwFileAttributes: windows.DWORD,
        psfi: ^SHFILEINFOW,
        cbFileInfo: windows.UINT,
        uFlags: windows.UINT,
    ) -> windows.DWORD_PTR ---
}

SHGFI_ICON      :: 0x000000100
SHGFI_LARGEICON :: 0x000000000
SHGFI_SMALLICON :: 0x000000001

// Gives every discovered app a name, a path, and the confidence to become clickable someday.
App_Entry :: struct {
    name : string,
    path : string,
    icon: ^d3d.IShaderResourceView
}

// Stands heroically empty, ready for whatever Shell abstraction tomorrow throws at it.
Shell_API :: struct {

}



// Current-user shortcuts are scanned first so a personal shortcut wins a
// same-named duplicate from the all-users menu.
start_menu_roots :: proc() -> (roots: [2]string, count: int) {
    app_data := os.get_env("APPDATA", context.temp_allocator)
    if app_data != "" {
        if path, err := os.join_path(
            {app_data, "Microsoft", "Windows", "Start Menu", "Programs"},
            context.temp_allocator,
        ); err == nil {
            roots[count] = path
            count += 1
        }
    }
    program_data := os.get_env("ProgramData", context.temp_allocator)
    if program_data == "" do program_data = "C:/ProgramData"
    if path, err := os.join_path(
        {program_data, "Microsoft", "Windows", "Start Menu", "Programs"},
        context.temp_allocator,
    ); err == nil {
        roots[count] = path
        count += 1
    }
    return
}

app_name_is_cached :: proc(state: ^App_State, name: string) -> bool {
    for key in state.app_order {
        if entry, ok := state.app[key]; ok && strings.equal_fold(entry.name, name) {
            return true
        }
    }
    return false
}

scan_start_menu :: proc(menu: ^Menu, root: string) {
    if root == "" || !os.exists(root) do return
    walker := os.walker_create(root)
    defer os.walker_destroy(&walker)

    for info in os.walker_walk(&walker) {
        if path, err := os.walker_error(&walker); err != nil {
            fmt.eprintfln("warning: failed walking %s: %s", path, err)
            continue
        }
        if len(info.fullpath) < 4 ||
           !strings.equal_fold(info.fullpath[len(info.fullpath)-4:], ".lnk") {
            continue
        }
        name_view := info.name
        if len(name_view) >= 4 do name_view = name_view[:len(name_view)-4]
        if app_name_is_cached(global_state, name_view) do continue

        file_info: SHFILEINFOW
        result := SHGetFileInfoW(
            windows.utf8_to_wstring(info.fullpath),
            0,
            &file_info,
            windows.UINT(size_of(SHFILEINFOW)),
            SHGFI_ICON | SHGFI_LARGEICON,
        )
        if result == 0 do continue

        srv := icon_to_texture(file_info.hIcon, menu)
        windows.DestroyIcon(file_info.hIcon)
        name := strings.clone(name_view)
        path := strings.clone(info.fullpath)
        global_state.app[path] = {name = name, path = path, icon = srv}
        append(&global_state.app_order, path)
    }
}

// Rallies both Start Menu locations into one reusable, deduplicated cache.
cache_start_apps :: proc(menu: ^Menu) {
    if global_state.apps_discovered {
        return
    }
    global_state.apps_discovered = true
    roots, count := start_menu_roots()
    for root in roots[:count] do scan_start_menu(menu, root)
    global_state.app_cache_updated_at = time.tick_now()
    log.infof("cached %d Start Menu shortcuts from %d locations", len(global_state.app_order), count)
}

app_cache_is_stale :: proc(state: ^App_State) -> bool {
    interval := state.menu.config.app_refresh_interval_seconds
    if !state.apps_discovered do return true
    if interval <= 0 do return false
    return time.tick_since(state.app_cache_updated_at) >= time.Second * time.Duration(interval)
}

refresh_start_apps_if_stale :: proc(state: ^App_State) {
    if state == nil || !app_cache_is_stale(state) do return
    // Nodes borrow cache strings and textures, so retire them before the cache.
    destroy_ui_tree(&state.root)
    destroy_start_app_cache(state)
    state.app = make(map[string]App_Entry)
    cache_start_apps(&state.menu)
    rebuild_search_results(state)
    log.info("refreshed Start Menu shortcut cache")
}

// Retires cached app resources gracefully after their long career launching things.
destroy_start_app_cache :: proc(state: ^App_State) {
    for key in state.app_order {
        _, entry := delete_key(&state.app, key)
        if entry.icon != nil {
            entry.icon.Release(cast(^windows.IUnknown)entry.icon)
        }
        delete(entry.name)
        delete(entry.path)
    }

    delete(state.app_order)
    delete(state.app)
    state.app_order = nil
    state.app = nil
    state.apps_discovered = false
}
