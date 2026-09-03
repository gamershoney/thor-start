package main


import "core:fmt"
import "core:mem"
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
start_button: ^IUIAutomationElement = nil
thor_icon_rect: windows.RECT
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

    hr = taskelement.lpvtbl.FindFirst(
        taskelement,
        .TreeScope_Subtree,
        condition,
        &start_button
    )

    if start_button == nil {
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

    hr = start_button.lpvtbl.get_CurrentBoundingRectangle(
        start_button,
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

	context = runtime.default_context()

	switch umsg {
	case windows.WM_TIMER:
		if start_button != nil {
			current_rect: windows.RECT
			hr := start_button.lpvtbl.get_CurrentBoundingRectangle(
				start_button,
				&current_rect,
			)

			if windows.SUCCEEDED(hr) {
				old_width := thor_icon_rect.right - thor_icon_rect.left
				old_height := thor_icon_rect.bottom - thor_icon_rect.top
				new_width := current_rect.right - current_rect.left
				new_height := current_rect.bottom - current_rect.top
				size_changed := old_width != new_width || old_height != new_height
				position_changed :=
					thor_icon_rect.left != current_rect.left ||
					thor_icon_rect.top != current_rect.top

				if size_changed {
					update_thor_icon(hwnd, current_rect)
				} else if position_changed {
					windows.SetWindowPos(
						hwnd,
						windows.HWND_TOPMOST,
						current_rect.left,
						current_rect.top,
						0,
						0,
						windows.SWP_NOSIZE |
						windows.SWP_NOACTIVATE |
						windows.SWP_SHOWWINDOW,
					)
					thor_icon_rect = current_rect
				} else {
					windows.SetWindowPos(
						hwnd,
						windows.HWND_TOPMOST,
						0, 0, 0, 0,
						windows.SWP_NOMOVE |
						windows.SWP_NOSIZE |
						windows.SWP_NOACTIVATE |
						windows.SWP_SHOWWINDOW,
					)
				}
			}
		}
    }
	fmt.println(umsg)

    return windows.DefWindowProcW(
        hwnd,
        umsg,
        wparam,
        lparam
    )
}


update_thor_icon :: proc "system" (
	hwnd: windows.HWND,
	rect: windows.RECT,
) -> bool {
	context = runtime.default_context()

	target_width := int(rect.right - rect.left)
	target_height := int(rect.bottom - rect.top)
	if hwnd == nil || target_width <= 0 || target_height <= 0 {
		return false
	}

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
		return false
	}
	defer png.destroy(img)

	if img.width <= 0 || img.height <= 0 || img.channels != 4 {
		fmt.println("Thor icon must decode as a non-empty RGBA image")
		return false
	}

	screen_dc := windows.GetDC(nil)
	if screen_dc == nil {
		fmt.printfln("GetDC failed: %d", windows.GetLastError())
		return false
	}
	defer windows.ReleaseDC(nil, screen_dc)

	memory_dc := windows.CreateCompatibleDC(screen_dc)
	if memory_dc == nil {
		fmt.printfln(
			"CreateCompatibleDC failed: %d",
			windows.GetLastError(),
		)
		return false
	}
	defer windows.DeleteDC(memory_dc)

	// A negative height produces a top-down DIB, matching the decoded image.
	bmi := windows.BITMAPINFO{
		bmiHeader = {
			biSize = size_of(windows.BITMAPINFOHEADER),
			biWidth = i32(target_width),
			biHeight = -i32(target_height),
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
		return false
	}
	defer windows.DeleteObject(cast(windows.HGDIOBJ)bitmap)

	old_bitmap := windows.SelectObject(
		memory_dc,
		cast(windows.HGDIOBJ)bitmap,
	)
	if old_bitmap == nil {
		fmt.printfln("SelectObject failed: %d", windows.GetLastError())
		return false
	}
	defer windows.SelectObject(memory_dc, old_bitmap)

	// Fit the image inside the live Start-button rectangle without stretching
	// it when the taskbar changes size or orientation.
	dst := cast([^]u8)pixels_raw
	mem.zero_slice(dst[:target_width * target_height * 4])

	scale_x := f32(target_width) / f32(img.width)
	scale_y := f32(target_height) / f32(img.height)
	scale := min(scale_x, scale_y)
	draw_width := max(1, int(f32(img.width) * scale + 0.5))
	draw_height := max(1, int(f32(img.height) * scale + 0.5))
	offset_x := (target_width - draw_width) / 2
	offset_y := (target_height - draw_height) / 2

	for y in 0..<draw_height {
		source_y := min(y * img.height / draw_height, img.height - 1)
		for x in 0..<draw_width {
			source_x := min(x * img.width / draw_width, img.width - 1)
			source_offset := (source_y * img.width + source_x) * 4
			dest_x := offset_x + x
			dest_y := offset_y + y
			dest_offset := (dest_y * target_width + dest_x) * 4

			// Decoded pixels are RGBA; a 32-bit Windows DIB is BGRA.
			dst[dest_offset + 0] = img.pixels.buf[source_offset + 2]
			dst[dest_offset + 1] = img.pixels.buf[source_offset + 1]
			dst[dest_offset + 2] = img.pixels.buf[source_offset + 0]
			dst[dest_offset + 3] = img.pixels.buf[source_offset + 3]
		}
	}

	dst_point := windows.POINT{x = rect.left, y = rect.top}
	src_point := windows.POINT{x = 0, y = 0}
	size := windows.SIZE{
		cx = i32(target_width),
		cy = i32(target_height),
	}
	blend := windows.BLENDFUNCTION{
		BlendOp = windows.AC_SRC_OVER,
		BlendFlags = 0,
		SourceConstantAlpha = 255,
		AlphaFormat = windows.AC_SRC_ALPHA,
	}

	if !UpdateLayeredWindow(
		hwnd,
		screen_dc,
		&dst_point,
		&size,
		memory_dc,
		&src_point,
		0,
		&blend,
		ULW_ALPHA,
	) {
		fmt.printfln(
			"UpdateLayeredWindow failed: %d",
			windows.GetLastError(),
		)
		return false
	}

	thor_icon_rect = rect
	return true
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
	if !update_thor_icon(icon, rect) {
		windows.DestroyWindow(icon)
		return
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
