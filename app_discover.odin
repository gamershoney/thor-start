package main

import "base:runtime"
import "core:os"
import "core:fmt"
import "core:strings"
import "core:sys/windows"
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



// Rallies Start Menu shortcuts into one reusable cache and gives each a shiny GPU hat.
cache_start_apps :: proc(menu: ^Menu) {
    if global_state.apps_discovered {
        return
    }
    global_state.apps_discovered = true

    walker := os.walker_create("C:/ProgramData/Microsoft/Windows/Start Menu/Programs")
    defer os.walker_destroy(&walker)

    for info in os.walker_walk(&walker) {
        if path, err := os.walker_error(&walker); err != nil {
			fmt.eprintfln("failed walking %s: %s", path, err)
			continue
		}

        if !strings.has_suffix(info.fullpath, ".lnk"){
            continue
        }

        file_info : SHFILEINFOW
        
        wide_path := windows.utf8_to_wstring(info.fullpath)

        result :=  SHGetFileInfoW(
                wide_path,
                0,
                &file_info,
                windows.UINT(size_of(SHFILEINFOW)),
                SHGFI_ICON | SHGFI_LARGEICON,
            )

            if result == 0 {
                continue
            }
        
        
        srv := icon_to_texture(
                file_info.hIcon,
                menu)
        windows.DestroyIcon(file_info.hIcon)
        name := strings.clone(strings.trim_suffix(info.name, ".lnk"))
        path := strings.clone(info.fullpath)
        entry := App_Entry{
            name = name,
            path = path,
            icon = srv,
        }

        if _, already_cached := global_state.app[path]; already_cached {
            if entry.icon != nil {
                entry.icon.Release(cast(^windows.IUnknown)entry.icon)
            }
            delete(entry.name)
            delete(entry.path)
            continue
        }

        global_state.app[path] = entry
        append(&global_state.app_order, path)

    }
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
