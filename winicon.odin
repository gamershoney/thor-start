package main


import "core:fmt"
import windows "core:sys/windows"
foreign import OleAut32 "system:OleAut32.lib"

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
    return windows.DefWindowProcW(
        hwnd,
        umsg,
        wparam,
        lparam
    )
}


drawThorIcon :: proc "system" (rect: windows.RECT){
    style := windows.WS_EX_LAYERED|windows.WS_EX_TOPMOST | windows.WS_EX_TOOLWINDOW|windows.WS_EX_NOACTIVATE
    classname : cstring16 = "Thor Icon Clas"
    instance := windows.GetModuleHandleW(nil)
    wndClass : windows.WNDCLASSW
    wndClass.lpszClassName = classname
    wndClass.lpfnWndProc = overlay
    wndClass.hInstance = cast(windows.HINSTANCE)instance

}