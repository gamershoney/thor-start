package main


import "core:fmt"
import windows "core:sys/windows"

rawCLSID : cstring16 : "{ff48dba4-60ef-4201-aa87-54103eef594e}"
rawIID : cstring16 : "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}"
clpointer: windows.GUID
iuipointer : windows.IID

wCLSID :: proc()->^windows.GUID{
    clsid: windows.HRESULT = windows.CLSIDFromString(
        rawCLSID,
        &clpointer
    )

    if clsid < 0{
        fmt.printfln("error on cslid: %#x",cast(u32)clsid)
    }

    return &clpointer
}

IID_IUIAutomation :: proc()-> ^windows.IID{
    iid : windows.HRESULT = windows.IIDFromString(
        rawIID,
        &iuipointer
    )
    return &iuipointer
}

automation : rawptr = nil
uiAutoErr :: distinct string

IUIAutomationVtable :: struct{
    using windows.IUnknownVtbl
//vtable and interfaces here
}

IUIAutomation:: struct{
    lpVtbl: ^IUIAutomationVtable
}



initUIAuto :: proc ()->uiAutoErr{
    err :uiAutoErr = ""
    hr : windows.HRESULT = windows.CoInitialize(nil)
    if cast(i32)hr < 0{
        err = "error: cannot initialize com communications"
        return err
    }
   hr = windows.CoCreateInstance(
        wCLSID(),
        nil,
        0x1,
        IID_IUIAutomation(),
        &automation
)
    if cast(i32)hr < 0{
        errs := windows.GetLastError()
        err = cast(uiAutoErr)fmt.tprintf("error: failure on CoCreateInstance: %#x \n LastCode: %x", cast(u32)hr,errs)
        return err
    }
    return err
}