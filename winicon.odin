package main


import "core:fmt"
import "base:runtime"
import windows "core:sys/windows"
import "core:image"
import "core:image/png"

foreign import OleAut32 "system:OleAut32.lib"
foreign import User32 "system:User32.lib"

rawCLSID: cstring16 : "{ff48dba4-60ef-4201-aa87-54103eef594e}"
rawIID: cstring16 : "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}"
clpointer: windows.GUID
iuipointer: windows.IID
windowhandle : cstring16 : "Shell_TrayWnd"
wCLSID :: proc() -> ^windows.GUID {
	clsid: windows.HRESULT = windows.CLSIDFromString(rawCLSID, &clpointer)

	if clsid < 0 {
		fmt.printfln("error on cslid: %#x", cast(u32)clsid)
	}

	return &clpointer
}

IID_IUIAutomation :: proc() -> ^windows.IID {
	iid: windows.HRESULT = windows.IIDFromString(rawIID, &iuipointer)
	return &iuipointer
}

foreign OleAut32 {
    SysAllocString :: proc "system"(
        psz: ^u16,
    ) -> windows.BSTR ---

    SysFreeString :: proc "system" (
        bstr: windows.BSTR,
    ) ---
}

foreign User32 {
    UpdateLayeredWindow :: proc "system"(
        hWnd : windows.HWND,
        hdcDst : windows.HDC,
        pptDst: ^windows.POINT,
        psize: ^windows.SIZE,
        hdcSrc: windows.HDC,
        pptSrc: ^windows.POINT,
        crKey: windows.COLORREF,
        pblend: ^windows.BLENDFUNCTION,
        dwFlags: windows.DWORD,
    ) -> windows.BOOL ---        

}

ULW_COLORKEY :: windows.DWORD(0x00000001)
ULW_ALPHA    :: windows.DWORD(0x00000002)
ULW_OPAQUE   :: windows.DWORD(0x00000004)

automation: ^IUIAutomation = nil
uiAutoErr :: distinct string


VARTYPE :: u16
SCODE :: i32
DATE :: f64

VARIANT_BOOL :: i16

VT_BSTR :: VARTYPE(8)

PROPERTYID :: i32

UIA_AutomationIdPropertyId: PROPERTYID : 30011

CY :: struct #raw_union {
	int64:       i64,
	using parts: struct {
		Lo: u32,
		Hi: i32,
	},
}

BRECORD :: struct {
	pvRecord: rawptr,
	pRecInfo: rawptr, // IRecordInfo *
}

VARIANT_VALUE :: struct #raw_union {
	llVal:        i64,
	lVal:         i32,
	bVal:         u8,
	iVal:         i16,
	fltVal:       f32,
	dblVal:       f64,
	boolVal:      VARIANT_BOOL,
	scode:        SCODE,
	cyVal:        CY,
	date:         DATE,
	bstrVal:      windows.BSTR,
	punkVal:      ^windows.IUnknown,
	pdispVal:     rawptr, // IDispatch *
	parray:       rawptr, // SAFEARRAY *
	pbVal:        ^u8,
	piVal:        ^i16,
	plVal:        ^i32,
	pllVal:       ^i64,
	pfltVal:      ^f32,
	pdblVal:      ^f64,
	pboolVal:     ^VARIANT_BOOL,
	pscode:       ^SCODE,
	pcyVal:       ^CY,
	pdate:        ^DATE,
	pbstrVal:     ^windows.BSTR,
	ppunkVal:     ^^windows.IUnknown,
	ppdispVal:    ^rawptr, // IDispatch **
	pparray:      ^rawptr, // SAFEARRAY **
	pvarVal:      rawptr, // VARIANT *; rawptr avoids recursive declaration trouble
	byref:        rawptr,
	cVal:         i8,
	uiVal:        u16,
	ulVal:        u32,
	ullVal:       u64,
	intVal:       i32,
	uintVal:      u32,
	pdecVal:      ^windows.DECIMAL,
	pcVal:        ^i8,
	puiVal:       ^u16,
	pulVal:       ^u32,
	pullVal:      ^u64,
	pintVal:      ^i32,
	puintVal:     ^u32,
	using record: BRECORD,
}

VARIANT_BODY :: struct {
	vt:          VARTYPE,
	wReserved1:  u16,
	wReserved2:  u16,
	wReserved3:  u16,
	using value: VARIANT_VALUE,
}

VARIANT :: struct #raw_union {
	using body: VARIANT_BODY,
	decVal:     windows.DECIMAL,
}

#assert(size_of(CY) == 8)
#assert(size_of(windows.DECIMAL) == 16)
#assert(size_of(VARIANT) == 24)

IUIAutomationVTable :: struct {
	using unknown:               windows.IUnknownVtbl,
	compareelements:             rawptr,
	compareruntimeids:           rawptr,
	getrootelement:              rawptr,
	elementfromhandle:           proc "system" (
		self: ^IUIAutomation,
		uia_hwnd: windows.HWND,
		element: ^^IUIAutomationElement,
	) -> windows.HRESULT,
	ElementFromPoint:            rawptr,
	GetFocusedElement:           rawptr,
	GetRootElementBuildCache:    rawptr,
	ElementFromHandleBuildCache: rawptr,
	ElementFromPointBuildCache:  rawptr,
	GetFocusedElementBuildCache: rawptr,
	CreateTreeWalker:            rawptr,
	get_ControlViewWalker:       rawptr,
	get_ContentViewWalker:       rawptr,
	get_RawViewWalker:           rawptr,
	get_RawViewCondition:        rawptr,
	get_ControlViewCondition:    rawptr,
	get_ContentViewCondition:    rawptr,
	CreateCacheRequest:          rawptr,
	CreateTrueCondition:         rawptr,
	CreateFalseCondition:        rawptr,
	CreatePropertyCondition:     proc "system" (
		self: ^IUIAutomation,
		propertyID: PROPERTYID,
		value: VARIANT,
		newCondition: ^^IUIAutomationCondition,
	) -> windows.HRESULT,
}

IUIAutomation :: struct {
	lpvtbl: ^IUIAutomationVTable,
}

TreeScope :: enum i32 {
	TreeScope_None        = 0,
	TreeScope_Element     = 0x1,
	TreeScope_Children    = 0x2,
	TreeScope_Descendants = 0x4,
	TreeScope_Parent      = 0x8,
	TreeScope_Ancestors   = 0x10,
	TreeScope_Subtree     = (TreeScope_Element | TreeScope_Children) | TreeScope_Descendants,
}

IUIAutomationCondition :: struct {
	lpvtbl: ^windows.IUnknownVtbl,
}

IUIAutomationElementVTable :: struct {
	using unknown:                   windows.IUnknownVtbl,
	SetFocus:                        rawptr,
	GetRuntimeId:                    rawptr,
	FindFirst:                       proc "system" (
		self: ^IUIAutomationElement,
		scope: TreeScope,
		condition: ^IUIAutomationCondition,
		found: ^^IUIAutomationElement,
	) -> windows.HRESULT,
	FindAll:                         rawptr,
	FindFirstBuildCache:             rawptr,
	FindAllBuildCache:               rawptr,
	BuildUpdatedCache:               rawptr,
	GetCurrentPropertyValue:         rawptr,
	GetCurrentPropertyValueEx:       rawptr,
	GetCachedPropertyValue:          rawptr,
	GetCachedPropertyValueEx:        rawptr,
	GetCurrentPatternAs:             rawptr,
	GetCachedPatternAs:              rawptr,
	GetCurrentPattern:               rawptr,
	GetCachedPattern:                rawptr,
	GetCachedParent:                 rawptr,
	GetCachedChildren:               rawptr,
	get_CurrentProcessId:            rawptr,
	get_CurrentControlType:          rawptr,
	get_CurrentLocalizedControlType: rawptr,
	get_CurrentName:                 rawptr,
	get_CurrentAcceleratorKey:       rawptr,
	get_CurrentAccessKey:            rawptr,
	get_CurrentHasKeyboardFocus:     rawptr,
	get_CurrentIsKeyboardFocusable:  rawptr,
	get_CurrentIsEnabled:            rawptr,
	get_CurrentAutomationId:         rawptr,
	get_CurrentClassName:            rawptr,
	get_CurrentHelpText:             rawptr,
	get_CurrentCulture:              rawptr,
	get_CurrentIsControlElement:     rawptr,
	get_CurrentIsContentElement:     rawptr,
	get_CurrentIsPassword:           rawptr,
	get_CurrentNativeWindowHandle:   rawptr,
	get_CurrentItemType:             rawptr,
	get_CurrentIsOffscreen:          rawptr,
	get_CurrentOrientation:          rawptr,
	get_CurrentFrameworkId:          rawptr,
	get_CurrentIsRequiredForForm:    rawptr,
	get_CurrentItemStatus:           rawptr,
	get_CurrentBoundingRectangle:    proc "system" (
		self: ^IUIAutomationElement,
		RECT: ^windows.RECT,
	) -> windows.HRESULT,
}

IUIAutomationElement :: struct {
	lpvtbl: ^IUIAutomationElementVTable,
}



initUIAuto :: proc() -> (uiAutoErr,windows.RECT) {
	err: uiAutoErr = ""
	rect :windows.RECT

	hr: windows.HRESULT = windows.CoInitialize(nil)
	if cast(i32)hr < 0 {
		err = "error: cannot initialize com communications"
		return err,rect
	}
	hr = windows.CoCreateInstance(
		wCLSID(),
		nil,
		0x1,
		IID_IUIAutomation(),
		cast(^rawptr)&automation,
	)
	if cast(i32)hr < 0 {
		errs := windows.GetLastError()
		err = cast(uiAutoErr)fmt.tprintf(
			"error: failure on CoCreateInstance: %#x \n LastCode: %x",
			cast(u32)hr,
			errs,
		)
		return err,rect
	}

    start_btn_txt : cstring16 = "StartButton"

    bstr := SysAllocString(cast(^u16)start_btn_txt)
    if bstr == nil {
        err: uiAutoErr = "error on allocating Start string"
        return err,rect
    }

    defer SysFreeString(bstr)

    value: VARIANT
    value.vt = VT_BSTR
    value.bstrVal = bstr

    condition: ^IUIAutomationCondition = nil

    hr = automation.lpvtbl.CreatePropertyCondition(
        automation,
        UIA_AutomationIdPropertyId,
        value,
        &condition,
    )

    if cast(i32)hr < 0 {
        err = cast(uiAutoErr)fmt.tprintf(
            "CreatePropertyContion failed: %#x",
            cast(u32)hr
        )
        return err,rect
    }

    taskbar := windows.FindWindowW(windowhandle, nil)
    taskelement : ^IUIAutomationElement = nil

    hr =automation.lpvtbl.elementfromhandle(
        automation,
        taskbar,
        &taskelement
    )
    if cast(i32)hr < 0{
        err = cast(uiAutoErr)fmt.tprintf(
            "Create task handle failed %#x",cast(u32)hr
        )
        return err,rect
    }

    startbtn : ^IUIAutomationElement = nil

    hr = taskelement.lpvtbl.FindFirst(
        taskelement,
        .TreeScope_Subtree,
        condition,
        &startbtn
    )

    if startbtn == nil {
    err = "FindFirst succeeded, but StartButton was not found"
    return err,rect
    }
    fmt.println("Found StartButton!")

    if cast(i32)hr < 0{
            err = cast(uiAutoErr)fmt.tprintf(
                "Find first task failed %#x",cast(u32)hr
            )
            return err,rect
    }	

    hr = startbtn.lpvtbl.get_CurrentBoundingRectangle(
        startbtn,
        &rect
    )

    if cast(i32)hr < 0{
		err = cast(uiAutoErr)fmt.tprintf(
			"Could not assign bounding rectangle: %#x",cast(u32)hr
		)
		return err,rect
	}

	fmt.print(rect.top,rect.bottom,rect.left,rect.right)
    return err,rect
}

overlay :: proc "system" (
    hwnd : windows.HWND,
    umsg : windows.UINT,
    wparam: windows.WPARAM,
    lparam: windows.LPARAM
)-> windows.LRESULT{

	switch umsg {
	case windows.WM_TIMER:
		windows.SetWindowPos(
			hwnd,
			windows.HWND_TOPMOST,
			0,0,0,0,
			windows.SWP_NOMOVE |
			windows.SWP_NOSIZE |
			windows.SWP_NOACTIVATE |
			windows.SWP_SHOWWINDOW
		)
    }
	context = runtime.default_context()
	fmt.println(umsg)

    return windows.DefWindowProcW(
        hwnd,
        umsg,
        wparam,
        lparam
    )
}


drawThorIcon :: proc "system" (rect: windows.RECT){

	context = runtime.default_context()

    style :=windows.WS_EX_LAYERED| windows.WS_EX_TOPMOST | windows.WS_EX_TOOLWINDOW|windows.WS_EX_NOACTIVATE
    classname : cstring16 = "Thor Icon Class"
    instance := windows.GetModuleHandleW(nil)
    wndClass : windows.WNDCLASSW
    wndClass.lpszClassName = classname
    wndClass.lpfnWndProc = overlay
    wndClass.hInstance = cast(windows.HINSTANCE)instance
	wndClass.hCursor = windows.LoadCursorA(
		nil,
		windows.IDC_ARROW
	)
	atom := windows.RegisterClassW(&wndClass);
	if atom == 0 {
		fmt.printfln(
        "RegisterClassW failed: %d",
        windows.GetLastError(),
    )
    return
	}
    width:= rect.right - rect.left
    height := rect.bottom - rect.top
	icon := windows.CreateWindowExW(
		style,
		classname,
		"ThorIcon",
		windows.WS_POPUP,
		rect.left,
		rect.top,
		width,
		height,
		nil,
		nil,
		cast(windows.HINSTANCE)instance,
		nil,
	)
fmt.printfln(
    "icon hwnd=%v x=%d y=%d w=%d h=%d",
    icon,
    rect.left,
    rect.top,
    rect.right - rect.left,
    rect.bottom - rect.top,
)
	if icon == nil {
    fmt.printfln(
        "CreateWindowExW failed: %d",
        windows.GetLastError(),
    )
    return
	}

    screen_dc := windows.GetDC(nil)
    defer windows.ReleaseDC(nil,screen_dc)

    memory_dc := windows.CreateCompatibleDC(screen_dc)
    defer windows.DeleteDC(memory_dc)

	options := image.Options{
    .alpha_add_if_missing,
    .alpha_premultiply,
	}

	img, err := image.load_from_file(
		"./icon.png",
		options,
		context.allocator,
	)
	if err != nil {
		fmt.println("Odin image load failed:", err)
		return
	}

	defer png.destroy(img)

fmt.println(
    "width:", img.width,
    "height:", img.height,
    "channels:", img.channels,
    "depth:", img.depth,
)

	bmi : windows.BITMAPINFO = {
		bmiHeader = {
			biSize = size_of(windows.BITMAPINFOHEADER),
			biWidth = width,
			biHeight = height,
			biPlanes = 1,
			biBitCount = 32,
			biCompression = windows.BI_RGB
		}
	}

	ptr : rawptr = nil
	bitmap := windows.CreateDIBSection(
		screen_dc,
		&bmi,
		windows.DIB_RGB_COLORS,
		&ptr,
		nil,
		0
	)

	dst := cast([^]u8)ptr
	
	pixel_count := img.width * img.height

	for i in 0..<pixel_count {
		offset := i*4
		dst[offset + 0] = img.pixels.buf[offset + 2]
		dst[offset + 1] = img.pixels.buf[offset + 1]
		dst[offset + 2] = img.pixels.buf[offset + 0]
		dst[offset + 3] = img.pixels.buf[offset + 3]

	} 

	if bitmap == nil {
		errcode := windows.GetLastError()
		fmt.printfln(
			"LoadImageW failed: %d (%#x)\n",
			cast(u32)errcode,
			cast(u32)errcode,
		)
		return
	}

    defer windows.DeleteObject(cast(windows.HGDIOBJ)bitmap)

    old_bitmap := windows.SelectObject(
        memory_dc,
        cast(windows.HGDIOBJ)bitmap,
    )

    defer windows.SelectObject(memory_dc, old_bitmap)

    dst_point := windows.POINT {
        x = rect.left,
        y = rect.top,
    }

    src_point := windows.POINT {
        x = 0,
        y = 0,
    }

    size := windows.SIZE {
        cx = width,
        cy = height,
    }
	
    blend := windows.BLENDFUNCTION{
        BlendOp             = windows.AC_SRC_OVER,
        BlendFlags          = 0,
        SourceConstantAlpha = 255,
        AlphaFormat         = windows.AC_SRC_ALPHA,
    }

    ok := UpdateLayeredWindow(
        icon,
        screen_dc,
        &dst_point,
        &size,
        memory_dc,
        &src_point,
        0,
        &blend,
        ULW_ALPHA
    )

    if !ok{
        fmt.printfln("UpdateLayeredWindow failed: %d",
        windows.GetLastError())
    }
    windows.ShowWindow(
    icon,
    windows.SW_SHOWNOACTIVATE,
	)

	windows.SetTimer(
		icon,
		1,
		250,
		nil
	)
}