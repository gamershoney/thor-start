package main


import "core:fmt"
import windows "core:sys/windows"

rawCLSID: cstring16 : "{ff48dba4-60ef-4201-aa87-54103eef594e}"
rawIID: cstring16 : "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}"
clpointer: windows.GUID
iuipointer: windows.IID

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

automation: ^IUIAutomation = nil
uiAutoErr :: distinct string

element :: ^rawptr

IUIAutomationVTable :: struct {
	using unknown:               windows.IUnknownVtbl,
	compareelements:             rawptr,
	compareruntimeids:           rawptr,
	getrootelement:              rawptr,
	elementfromhandle:           proc "system" (
		self: ^IUIAutomation,
		uia_hwnd: windows.HWND,
		IUIAutomationElement: ^^IUIAutomationElement,
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
		PropertyID: u32,
    value: 
	) -> windows.HRESULT,
}

IUIAutomation :: struct {
	lpvtbl: ^IUIAutomationVTable,
}

TreeScope :: enum {
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


initUIAuto :: proc() -> uiAutoErr {
	err: uiAutoErr = ""
	hr: windows.HRESULT = windows.CoInitialize(nil)
	if cast(i32)hr < 0 {
		err = "error: cannot initialize com communications"
		return err
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
		return err
	}
	return err
}
