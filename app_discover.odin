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
IShellApi : struct {

}



// Rallies Start Menu shortcuts into formation and gives each one a shiny GPU hat.
get_start_apps :: proc(menu:^Menu)->[dynamic]App_Entry{
    walker := os.walker_create("C:/ProgramData/Microsoft/Windows/Start Menu/Programs")
    defer os.walker_destroy(&walker)

    entries : [dynamic]App_Entry

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
        append(&entries,entry)

    }

    return entries
}
