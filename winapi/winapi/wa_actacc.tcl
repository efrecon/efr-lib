package require winapi::core

namespace eval ::winapi {
    variable WINAPI
    variable log
}


proc ::winapi::AccessibleObjectFromWindow { hwnd } {
    # GUID of IAccessible object is 618736E0-3C3D-11CF-810C-00AA00389B71
    set buf [binary format [::ffidl::info format ::winapi::GUID] \
		 [expr 0x618736E0] [expr 0x3C3D] [expr 0x11CF] \
		 [expr 0x81] [expr 0x0c] [expr 0x00] [expr 0xaa] \
		 [expr 0x00] [expr 0x38] [expr 0x9b] [expr 0x71]]
    
    set iface_ptr [binary format [::ffidl::info format ::winapi::LONG] 0]
    set res [::winapi::__AccessibleObjectFromWindow $hwnd 0 buf iface_ptr]
    binary scan $iface_ptr [::ffidl::info format ::winapi::LONG] iface

    return $iface
}


proc ::winapi::__init_actacc { } {
    variable WINAPI
    variable log

    # Make sure we can declare functions from the Accessibility DLL
    core::adddll oleacc

    # Local type defs
    ::ffidl::typedef ::winapi::GUID \
	"unsigned long" "unsigned short" "unsigned short" \
	::winapi::BYTE ::winapi::BYTE ::winapi::BYTE ::winapi::BYTE \
	::winapi::BYTE ::winapi::BYTE ::winapi::BYTE ::winapi::BYTE
    
    # Functions
    core::api __AccessibleObjectFromWindow \
	{ ::winapi::HWND ::winapi::DWORD pointer-var pointer-var } \
	::winapi::HRESULT

    return 1
}


# Now automatically initialises this module, once and only once
# through calling the __init procedure that was just declared above.
::winapi::core::initonce actacc ::winapi::__init_actacc

package provide winapi 0.2
