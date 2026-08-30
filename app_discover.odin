package main

import "base:runtime"
import "core:os"
import "core:fmt"
import "core:strings"
import "core:sys/windows"
foreign import Shell32 "system:shell32.lib"

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
        cbFileInfo: uint,
        uFlags: uint,
    ) -> windows.DWORD_PTR ---
}

App_Entry :: struct {
    name : string,
    app_id : string,
    parsing_name : string,
    //icon: 
}

IShellApi : struct {

}


get_start_apps :: proc()->[dynamic]App_Entry{
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
        
        path : cstring16 = cast(cstring16)info.fullpath

        SHGetFileInfoW(

        )
    }

    return entries
}