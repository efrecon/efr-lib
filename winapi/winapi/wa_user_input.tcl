package require winapi::core

namespace eval ::winapi {
    variable WINAPI
    variable log
}

# ::winapi::SendMouseInput -- Send simulated mouse input
#
#	This procedure is a wrapper around (the deprecated)
#	mouse_event function that is able to understand all the
#	MOUSEEVENTF_ flags as input.  It is called that way to hint to
#	the (new) SendInput function that replaces mouse_event.
#
# Arguments:
#	dx	Absolute or relative deplacement in X
#	dy	Absolute or relative deplacement in Y
#	flagsl	List of MOUSEEVENTF_ flags that describe the event.
#	dwData	Additional data to the event.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winapi::SendMouseInput { dx dy flagsl { dwData "" } } {
    set flags [core::flags $flagsl { "*ABSOLUTE" 32768 "*MOVE" 1 \
				     "*LEFTDOWN" 2 "*LEFTUP" 4 \
				     "*RIGHTDOWN" 8 "*RIGHTUP" 16 \
				     "*MIDDLEDOWN" 32 "*MIDDLEUP" 64 \
				     "*WHEEL" 2048 "*XDOWN" 128 "*XUP" 256}]
    set dwData [core::flags $dwData { "XBUTTON1" 1 "XBUTTON2" 2}]

    # Ideally, we would like to call SendInput, but it requires a
    # pointer to an structure that contains itself a pointer to an
    # array and I don't know how to imlement that with ffidl.
    mouse_event $flags $dx $dy $dwData 0
}


# ::winapi::SendKeyboardInput -- Send simulated keyboard input
#
#	This procedure is a wrapper around (the deprecated)
#	keybd_event function that is able to understand all the
#	VK_ flags as input.  It is called that way to hint to
#	the (new) SendInput function that replaces keybd_event.
#
# Arguments:
#	vk	Virtual key of the event
#	dwFlags	Flags describing the key event
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winapi::SendKeyboardInput { vk { dwFlags ""} } {
    set flags [core::flags $dwFlags { "*EXTENDEDKEY" 1 "*KEYUP" 2}]
    set vk [core::flag $vk [list  "*LBUTTON" [expr {0x01}] \
			    "*RBUTTON" [expr {0x02}] \
			     "*LCONTROL" [expr {0xA2}] \
			     "*RCONTROL" [expr {0xA3}] \
			     "*LSHIFT" [expr {0xA0}] \
			     "*RSHIFT" [expr {0xA1}] \
			     "*LMENU" [expr {0xA4}] \
			     "*RMENU" [expr {0xA5}] \
			     "*CANCEL" [expr {0x03}] \
			     "*MBUTTON" [expr {0x04}] \
			     "*XBUTTON1" [expr {0x05}] \
			     "*XBUTTON2" [expr {0x06}] \
			     "*BACK" [expr {0x08}] \
			     "*TAB" [expr {0x09}] \
			     "*CLEAR" [expr {0x0C}] \
			     "*RETURN" [expr {0x0D}] \
			     "*SHIFT" [expr {0x10}] \
			     "*CONTROL" [expr {0x11}] \
			     "*MENU" [expr {0x12}] \
			     "*PAUSE" [expr {0x13}] \
			     "*CAPITAL" [expr {0x14}] \
			     "*KANA" [expr {0x15}] \
			     "*HANGUEL" [expr {0x15}] \
			     "*HANGUL" [expr {0x15}] \
			     "*JUNJA" [expr {0x17}] \
			     "*FINAL" [expr {0x18}] \
			     "*HANJA" [expr {0x19}] \
			     "*KANJI" [expr {0x19}] \
			     "*ESCAPE" [expr {0x1B}] \
			     "*CONVERT" [expr {0x1C}] \
			     "*NONCONVERT" [expr {0x1D}] \
			     "*ACCEPT" [expr {0x1E}] \
			     "*MODECHANGE" [expr {0x1F}] \
			     "*SPACE" [expr {0x20}] \
			     "*PRIOR" [expr {0x21}] \
			     "*NEXT" [expr {0x22}] \
			     "*END" [expr {0x23}] \
			     "*HOME" [expr {0x24}] \
			     "*LEFT" [expr {0x25}] \
			     "*UP" [expr {0x26}] \
			     "*RIGHT" [expr {0x27}] \
			     "*DOWN" [expr {0x28}] \
			     "*SELECT" [expr {0x29}] \
			     "*PRINT" [expr {0x2A}] \
			     "*EXECUTE" [expr {0x2B}] \
			     "*SNAPSHOT" [expr {0x2C}] \
			     "*INSERT" [expr {0x2D}] \
			     "*DELETE" [expr {0x2E}] \
			     "*HELP" [expr {0x2F}] \
			     0 [expr {0x30}] \
			     1 [expr {0x31}] \
			     2 [expr {0x32}] \
			     3 [expr {0x33}] \
			     4 [expr {0x34}] \
			     5 [expr {0x35}] \
			     6 [expr {0x36}] \
			     7 [expr {0x37}] \
			     8 [expr {0x38}] \
			     9 [expr {0x39}] \
			     A [expr {0x41}] \
			     B [expr {0x42}] \
			     C [expr {0x43}] \
			     D [expr {0x44}] \
			     E [expr {0x45}] \
			     F [expr {0x46}] \
			     G [expr {0x47}] \
			     H [expr {0x48}] \
			     I [expr {0x49}] \
			     J [expr {0x4A}] \
			     K [expr {0x4B}] \
			     L [expr {0x4C}] \
			     M [expr {0x4D}] \
			     N [expr {0x4E}] \
			     O [expr {0x4F}] \
			     P [expr {0x50}] \
			     Q [expr {0x51}] \
			     R [expr {0x52}] \
			     S [expr {0x53}] \
			     T [expr {0x54}] \
			     U [expr {0x55}] \
			     V [expr {0x56}] \
			     W [expr {0x57}] \
			     X [expr {0x58}] \
			     Y [expr {0x59}] \
			     Z [expr {0x5A}] \
			     "*LWIN" [expr {0x5B}] \
			     "*RWIN" [expr {0x5C}] \
			     "*APPS" [expr {0x5D}] \
			     "*SLEEP" [expr {0x5F}] \
			     "*NUMPAD0" [expr {0x60}] \
			     "*NUMPAD1" [expr {0x61}] \
			     "*NUMPAD2" [expr {0x62}] \
			     "*NUMPAD3" [expr {0x63}] \
			     "*NUMPAD4" [expr {0x64}] \
			     "*NUMPAD5" [expr {0x65}] \
			     "*NUMPAD6" [expr {0x66}] \
			     "*NUMPAD7" [expr {0x67}] \
			     "*NUMPAD8" [expr {0x68}] \
			     "*NUMPAD9" [expr {0x69}] \
			     "*MULTIPLY" [expr {0x6A}] \
			     "*ADD" [expr {0x6B}] \
			     "*SEPARATOR" [expr {0x6C}] \
			     "*SUBTRACT" [expr {0x6D}] \
			     "*DECIMAL" [expr {0x6E}] \
			     "*DIVIDE" [expr {0x6F}] \
			     "*F1" [expr {0x70}] \
			     "*F2" [expr {0x71}] \
			     "*F3" [expr {0x72}] \
			     "*F4" [expr {0x73}] \
			     "*F5" [expr {0x74}] \
			     "*F6" [expr {0x75}] \
			     "*F7" [expr {0x76}] \
			     "*F8" [expr {0x77}] \
			     "*F9" [expr {0x78}] \
			     "*F10" [expr {0x79}] \
			     "*F11" [expr {0x7A}] \
			     "*F12" [expr {0x7B}] \
			     "*F13" [expr {0x7C}] \
			     "*F14" [expr {0x7D}] \
			     "*F15" [expr {0x7E}] \
			     "*F16" [expr {0x7F}] \
			     "*F17" [expr {0x80}] \
			     "*F18" [expr {0x81}] \
			     "*F19" [expr {0x82}] \
			     "*F20" [expr {0x83}] \
			     "*F21" [expr {0x84}] \
			     "*F22" [expr {0x85}] \
			     "*F23" [expr {0x86}] \
			     "*F24" [expr {0x87}] \
			     "*NUMLOCK" [expr {0x90}] \
			     "*SCROLL" [expr {0x91}] \
			     "*BROWSER_BACK" [expr {0xA6}] \
			     "*BROWSER_FORWARD" [expr {0xA7}] \
			     "*BROWSER_REFRESH" [expr {0xA8}] \
			     "*BROWSER_STOP" [expr {0xA9}] \
			     "*BROWSER_SEARCH" [expr {0xAA}] \
			     "*BROWSER_FAVORITES" [expr {0xAB}] \
			     "*BROWSER_HOME" [expr {0xAC}] \
			     "*VOLUME_MUTE" [expr {0xAD}] \
			     "*VOLUME_DOWN" [expr {0xAE}] \
			     "*VOLUME_UP" [expr {0xAF}] \
			     "*MEDIA_NEXT_TRACK" [expr {0xB0}] \
			     "*MEDIA_PREV_TRACK" [expr {0xB1}] \
			     "*MEDIA_STOP" [expr {0xB2}] \
			     "*MEDIA_PLAY_PAUSE" [expr {0xB3}] \
			     "*LAUNCH_MAIL" [expr {0xB4}] \
			     "*LAUNCH_MEDIA_SELECT" [expr {0xB5}] \
			     "*LAUNCH_APP1" [expr {0xB6}] \
			     "*LAUNCH_APP2" [expr {0xB7}] \
			     "*OEM_1" [expr {0xBA}] \
			     "*OEM_PLUS" [expr {0xBB}] \
			     "*OEM_COMMA" [expr {0xBC}] \
			     "*OEM_MINUS" [expr {0xBD}] \
			     "*OEM_PERIOD" [expr {0xBE}] \
			     "*OEM_2" [expr {0xBF}] \
			     "*OEM_3" [expr {0xC0}] \
			     "*OEM_4" [expr {0xDB}] \
			     "*OEM_5" [expr {0xDC}] \
			     "*OEM_6" [expr {0xDD}] \
			     "*OEM_7" [expr {0xDE}] \
			     "*OEM_8" [expr {0xDF}] \
			     "*OEM_102" [expr {0xE2}] \
			     "*PROCESSKEY" [expr {0xE5}] \
			     "*PACKET" [expr {0xE7}] \
			     "*ATTN" [expr {0xF6}] \
			     "*CRSEL" [expr {0xF7}] \
			     "*EXSEL" [expr {0xF8}] \
			     "*EREOF" [expr {0xF9}] \
			     "*PLAY" [expr {0xFA}] \
			     "*ZOOM" [expr {0xFB}] \
			     "*NONAME" [expr {0xFC}] \
			     "*PA1" [expr {0xFD}] \
			     "*OEM_CLEAR" [expr {0xFE}]] 1]
    keybd_event $vk 0 $flags 0
}


# ::winapi::GetMouseMovePoints -- Get mouse pointer history
#
#	This procedure retrieves a history of up to 64 previous
#	coordinates of the mouse or pen
#
# Arguments:
#	nbpts	Number of points to retrieve
#	res	Resolution
#	pt	List of x y (and time) of point in history to start at
#
# Results:
#	List of x1, y1, time1, x2, y2, time2, ... (empty if none).
#
# Side Effects:
#	None.
proc ::winapi::GetMouseMovePointsEx { nbpts res { pt {}} } {
    variable log

    if { [llength $pt] > 0 } {
	foreach {xold yold told} $pt {}
	if { $told == "" } { set told 0 }
	set old [binary format \
		     [::ffidl::info format ::winapi::MOUSEMOVEPOINT] \
		     $xold $yold $told 0]
    }

    set buf \
	[binary format x[expr $nbpts*[::ffidl::info \
					  sizeof ::winapi::MOUSEMOVEPOINT]]]

    set res [core::flag $res [list "*USE_DISPLAY_POINTS" 1 \
			      "*USE_HIGH_RESOLUTION_POINTS" 2]]

    if { [llength $pt] > 0 } {
	set res [__GetMouseMovePointsEx \
		     [::ffidl::info sizeof ::winapi::MOUSEMOVEPOINT] \
		     old buf $nbpts $res]
    } else {
	set res [__GetMouseMovePointsExNoPick \
		     [::ffidl::info sizeof ::winapi::MOUSEMOVEPOINT] \
		     0 buf $nbpts $res]
    }
    
    set points [list]
    if { $res >= 0 } {
	for { set i 0 } { $i < $res } { incr i } {
	    set fmt \
		[format "@%d%s" \
		     [expr [::ffidl::info alignof ::winapi::MOUSEMOVEPOINT]*$i] \
		     [::ffidl::info format ::winapi::MOUSEMOVEPOINT]]
	    binary scan $buf $fmt x y t extra
	    lappend points $x $y $t
	}
    } else {
	${log}::warn "Error when getting points: [::winapi::GetLastError]"
    }
    return $points
}


# ::winapi::GetCursorPos -- Get Cursor position
#
#	This procedure retrieves the position of the current cursor
#	(mouse pointer!)
#
# Arguments:
#
# Results:
#	List composed of the x and y coordinates of the cursor, or
#	empty on error.
#
# Side Effects:
#	None.
proc ::winapi::GetCursorPos { } {
    set buf [binary format x[::ffidl::info sizeof ::winapi::POINT]]
    if { [__GetCursorPos buf] } {
	binary scan $buf [::ffidl::info format ::winapi::POINT] x y
	return [list $x $y]
    } else {
	return [list]
    }
}


# ::winapi::MenuItemFromPoint -- Get menu item under point
#
#	LongDescr.
#
# Arguments:
#	menu	Handle to the menu
#	X	X position in screen coordinates
#	Y	Y position in screen coordinates
#	w	Handle to window containing the menu
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winapi::MenuItemFromPoint { menu x y { w "" } } {
    set buf [binary format [::ffidl::info format ::winapi::POINT] $x $y]
    if { $w eq "" } {
	set itm [__MenuItemFromPoint_nowin 0 $menu buf]
    } else {
	set itm [__MenuItemFromPoint $w $menu buf]
    }

    return $itm
}


# ::winapi::GetMenuBarInfo -- Get menu bar info
#
#	This procedure retrieves information about the specified menu
#	bar.  The menu object will be: the popup menu associated with
#	the window (obj == OBJID_CLIENT), the menubar associated to
#	the window (OBJID_MENU) or the system menu associated to the
#	window (OBJID_SYSMENU).
#
# Arguments:
#	w	Handle to the window (menu bar) whose information we want
#	obj	One of OBJID_CLIENT, OBJID_MENU or OBJID_SYSMENU
#	item    Item to retrieve info for: 0 for the menu itself, 1 for
#	        first item, etc.
#
# Results:
#	An empty list on error, or a list ready for an array-set
#	command which mirrors the MENUBARINFO structure.
#
# Side Effects:
#	None.
proc ::winapi::GetMenuBarInfo { w obj item } {
    variable WINAPI
    variable log

    set buf [binary format \
		 "x[::ffidl::info sizeof ::winapi::MENUBARINFO]@0i1" \
		 [::ffidl::info sizeof ::winapi::MENUBARINFO]]
    set obj [core::flag $obj [list \
				  "*CLIENT"    [expr 0xFFFFFFFC] \
				  "*SYSMENU"   [expr 0xFFFFFFFF] \
				  "*MENU"      [expr 0xFFFFFFFD]]]
    set res [__GetMenuBarInfo $w $obj $item buf]
    if { $res } {
	binary scan $buf [::ffidl::info format ::winapi::MENUBARINFO] \
	    len \
	    info(rcBarLeft) info(rcBarTop) info(rcBarRight) info(rcBarBottom) \
	    info(hMenu) info(hwndMenu) flags
	set info(fBarFocused) [expr $flags & 0x1]
	set info(fFocused) [expr $flags & 0x2]

	return [array get info]
    }
    return [list]
}


# ::winapi::GetMenuInfo -- Get menu information
#
#	The procedure gets information about a specified menu
#
# Arguments:
#	menu	Handle to a menu
#
# Results:
#	Return an empty list on failure, of all the members of the
#	MENUINFO structure.
#
# Side Effects:
#	None.
proc ::winapi::GetMenuInfo { menu {what {BACKGROUND HELPID MAXHEIGHT MENUDATA STYLE}}} {
    variable WINAPI
    variable log

    set req [core::flags $what \
		 [list \
		      "*APPLYTOSUBMENUS"  [expr 0x80000000] \
		      "*BACKGROUND"       2 \
		      "*HELPID"           4 \
		      "*MAXHEIGHT"        1 \
		      "*MENUDATA"         8 \
		      "*STYLE"            16]]
    set buf [binary format \
		 "x[::ffidl::info sizeof ::winapi::MENUINFO]@0i1i1" \
		 [::ffidl::info sizeof ::winapi::MENUINFO] $req]
    set res [__GetMenuInfo $menu buf]
    if { $res } {
	binary scan $buf [::ffidl::info format ::winapi::MENUINFO] \
	    len fMask \
	    info(dwStyle) info(cyMax) info(hbrBack) info(dwContextHelpID) \
	    info(dwMenuData)
	set info(dwStyle) \
	    [core::tflags $info(dwStyle) \
		 [list \
		      "MNS_NOCHECK"     [expr 0x80000000] \
		      "MNS_MODELESS"    [expr 0x40000000] \
		      "MNS_DRAGDROP"    [expr 0x20000000] \
		      "MNS_AUTODISMISS" [expr 0x10000000] \
		      "MNS_NOTIFYBYPOS" [expr 0x08000000] \
		      "MNS_CHECKORBMP"  [expr 0x04000000]]]
	
	return [array get info]
    }
    return [list]
}


proc ::winapi::SetMenuInfo { menu valspecs {what {BACKGROUND HELPID MAXHEIGHT MENUDATA STYLE}}} {
    variable WINAPI
    variable log

    array set info {
	fMask           0
	dwStyle         0
	cyMax           0
	hbrBack         0
	dwContextHelpID 0
	dwMenuData      0
    }
    set info(cbSize) [::ffidl::info sizeof ::winapi::MENUINFO]
    array set info $valspecs
    set info(fMask) [core::flags $what \
			 [list \
			      "*APPLYTOSUBMENUS"  [expr 0x80000000] \
			      "*BACKGROUND"       2 \
			      "*HELPID"           4 \
			      "*MAXHEIGHT"        1 \
			      "*MENUDATA"         8 \
			      "*STYLE"            16]]
    set info(dwStyle) [core::flags $info(dwStyle) \
			   [list \
				"*NOCHECK"     [expr 0x80000000] \
				"*MODELESS"    [expr 0x40000000] \
				"*DRAGDROP"    [expr 0x20000000] \
				"*AUTODISMISS" [expr 0x10000000] \
				"*NOTIFYBYPOS" [expr 0x08000000] \
				"*CHECKORBMP"  [expr 0x04000000]]]
    set buf [binary format [::ffidl::info format ::winapi::MENUINFO] \
		 $info(cbSize) $info(fMask) $info(dwStyle) \
		 $info(cyMax) $info(hbrBack) $info(dwContextHelpID) \
		 $info(dwMenuData)]
    return [__SetMenuInfo $menu buf]
}


proc ::winapi::GetMenuItemInfo { menu item bypos } {
    variable WINAPI
    variable log

    set reqdefs [list \
		     "*BITMAP"       128 \
		     "*CHECKMARKS"   8   \
		     "*DATA"         32  \
		     "*FTYPE"        256 \
		     "*ID"           2   \
		     "*STATE"        1   \
		     "*STRING"       64  \
		     "*SUBMENU"      4   \
		     "*TYPE"         16]
    set typedefs [list \
		      MFT_STRING          [expr 0x0] \
		      MFT_BITMAP          [expr 0x4] \
		      MFT_MENUBARBREAK    [expr 0x20] \
		      MFT_MENUBREAK       [expr 0x40] \
		      MFT_OWNERDRAW       [expr 0x100] \
		      MFT_RADIOCHECK      [expr 0x200] \
		      MFT_RIGHTJUSTIFY    [expr 0x4000] \
		      MFT_SEPARATOR       [expr 0x800] \
		      MFT_RIGHTORDER      [expr 0x2000]]

    # First ask windows the size of the string if any.
    set req [core::flags {FTYPE STRING} $reqdefs]
    set buf [binary format \
		 "x[::ffidl::info sizeof ::winapi::MENUITEMINFO]@0i1i1" \
		 [::ffidl::info sizeof ::winapi::MENUITEMINFO] $req]
    set res [__GetMenuItemInfo $menu $item [string is true $bypos] buf]
    if { ! $res } {
	return [list]
    }
    binary scan $buf [::ffidl::info format ::winapi::MENUITEMINFO] \
	len req \
	preinfo(fType) preinfo(fState) preinfo(wID) preinfo(hSubMenu) \
	preinfo(hbmpChecked) preinfo(hbmpUnchecked) preinfo(dwItemData) \
	preinfo(dwTypeData) preinfo(cch) preinfo(hbmpItem)
    set preinfo(fType) [core::tflag $preinfo(fType) $typedefs]
    if { $preinfo(fType) == "MFT_STRING" } {
	set cch [expr $preinfo(cch) + 1]
	set ptr [::ffidl::malloc $cch]
    } else {
	set cch 0
	set ptr 0
    }

    # Now request for all possible information
    set req [core::flags {BITMAP CHECKMARKS DATA FTYPE ID \
			      STATE STRING SUBMENU} \
		 $reqdefs]
    set buf [binary format [::ffidl::info format ::winapi::MENUITEMINFO] \
		 $len $req \
		 0 0 0 0 0 0 0 $ptr $cch 0]
    set res [__GetMenuItemInfo $menu $item [string is true $bypos] buf]
    if { ! $res } {
	return [list]
    }
    binary scan $buf [::ffidl::info format ::winapi::MENUITEMINFO] \
	len req \
	info(fType) info(fState) info(wID) info(hSubMenu) \
	info(hbmpChecked) info(hbmpUnchecked) info(dwItemData) \
	info(dwTypeData) info(cch) info(hbmpItem)
    set info(fType) [core::tflag $info(fType) $typedefs]
    set info(fState) [core::tflags $info(fState) \
			  [list \
			       MFS_CHECKED         [expr 0x8] \
			       MFS_DEFAULT         [expr 0x1000] \
			       MFS_DISABLED        [expr 0x3] \
			       MFS_ENABLED         [expr 0x0] \
			       MFS_GRAYED          [expr 0x3] \
			       MFS_HILITE          [expr 0x80] \
			       MFS_UNCHECKED       [expr 0x0] \
			       MFS_UNHILITE        [expr 0x0]]]
    set info(hbmpItem) [core::tflag $info(hbmpItem) \
			    [list \
				 HBMMENU_CALLBACK         (-1) \
				 HBMMENU_SYSTEM           (1) \
				 HBMMENU_MBAR_RESTORE     (2) \
				 HBMMENU_MBAR_MINIMIZE    (3) \
				 HBMMENU_MBAR_CLOSE       (5) \
				 HBMMENU_MBAR_CLOSE_D     (6) \
				 HBMMENU_MBAR_MINIMIZE_D  (7) \
				 HBMMENU_POPUP_CLOSE      (8) \
				 HBMMENU_POPUP_RESTORE    (9) \
				 HBMMENU_POPUP_MAXIMIZE   (10) \
				 HBMMENU_POPUP_MINIMIZE   (11)]]
    if { $info(fType) == "MFT_STRING" } {
	set menustr [::ffidl::peek $ptr [expr $cch-1]]
	binary scan $menustr a* info(dwTypeData)
	if { [string is true $WINAPI(unicode)] } {
	    set info(dwTypeDate) \
		[encoding convertfrom unicode $info(dwTypeData)]
	}
	::ffidl::free $ptr
    }
    
    return [array get info]
}


proc ::winapi::GetMenuItemRect { menu item { hwnd 0 } } {
    variable WINAPI
    variable log

    set rect [binary format "x[::ffidl::info sizeof ::winapi::RECT]"]
    set res [__GetMenuItemRect $hwnd $menu $item rect]
    if { $res } {
	binary scan $rect [::ffidl::info format ::winapi::RECT] \
	    left top right bottom
	return [list $left $top $right $bottom]
    }
    return [list]
}



proc ::winapi::__init_user_input { } {
    variable WINAPI
    variable log
    
    # Local type defs
    ::ffidl::typedef ::winapi::MOUSEMOVEPOINT int int uint32 long
    ::ffidl::typedef ::winapi::HMENU ::winapi::HANDLE
    ::ffidl::typedef ::winapi::HBRUSH ::winapi::HANDLE
    ::ffidl::typedef ::winapi::HBITMAP ::winapi::HANDLE
    ::ffidl::typedef ::winapi::MENUBARINFO \
	::winapi::DWORD ::winapi::RECT ::winapi::HMENU ::winapi::HWND \
	::winapi::DWORD
    ::ffidl::typedef ::winapi::MENUINFO \
	::winapi::DWORD ::winapi::DWORD ::winapi::DWORD \
	::winapi::UINT ::winapi::HBRUSH ::winapi::DWORD \
	::winapi::ULONG_PTR
    ::ffidl::typedef ::winapi::MENUITEMINFO \
	::winapi::UINT ::winapi::UINT ::winapi::UINT ::winapi::UINT \
	::winapi::UINT ::winapi::HMENU ::winapi::HBITMAP ::winapi::HBITMAP \
	::winapi::ULONG_PTR pointer ::winapi::UINT ::winapi::HBITMAP
    ::ffidl::typedef ::winapi::TCHAR sint8

    # User Input
    core::api SendInput { ::winapi::UINT pointer-var int } ::winapi::UINT
    core::api mouse_event \
	{ ::winapi::DWORD ::winapi::DWORD ::winapi::DWORD ::winapi::DWORD \
	      ::winapi::ULONG_PTR } void
    core::api keybd_event \
	{ ::winapi::BYTE ::winapi::BYTE ::winapi::DWORD ::winapi::PTR } void
    core::api __GetMouseMovePointsEx \
	{ ::winapi::UINT pointer-var pointer-var int ::winapi::DWORD } int
    core::api __GetMouseMovePointsExNoPick \
	{ ::winapi::UINT ::winapi::PTR pointer-var int ::winapi::DWORD } int \
	GetMouseMovePointsEx
    core::api __GetCursorPos { pointer-var } ::winapi::BOOL
    core::api SetFocus { ::winapi::HWND } ::winapi::HWND
    core::api GetFocus {} ::winapi::HWND
    core::api GetActiveWindow {} ::winapi::HWND
    core::api SetActiveWindow {::winapi::HWND} ::winapi::HWND
    core::api GetDoubleClickTime {} ::winapi::UINT
    core::api VkKeyScan {::winapi::TCHAR} short

    # Menus
    core::api GetMenu {::winapi::HWND} ::winapi::HMENU
    core::api IsMenu {::winapi::HMENU} ::winapi::BOOL
    core::api __MenuItemFromPoint \
	{::winapi::HWND ::winapi::HMENU pointer-var} int MenuItemFromPoint
    core::api __MenuItemFromPoint_nowin \
	{pointer ::winapi::HMENU pointer-var} int MenuItemFromPoint
    core::api GetMenuItemID {::winapi::HMENU int} ::winapi::UINT
    core::api GetSubMenu {::winapi::HMENU int} ::winapi::HMENU
    core::api GetMenuItemCount {::winapi::HMENU} int
    core::api __GetMenuBarInfo {::winapi::HWND ::winapi::LONG ::winapi::LONG \
				    pointer-var} ::winapi::BOOL
    core::api __GetMenuInfo {::winapi::HMENU pointer-var} ::winapi::BOOL
    core::api __SetMenuInfo {::winapi::HMENU pointer-var} ::winapi::BOOL
    core::api __GetMenuItemInfo {::winapi::HMENU ::winapi::UINT \
				     ::winapi::BOOL pointer-var} ::winapi::BOOL
    core::api __GetMenuItemRect {::winapi::HWND ::winapi::HMENU \
				     ::winapi::UINT pointer-var} ::winapi::BOOL

    return 1
}

# Now automatically initialises this module, once and only once
# through calling the __init procedure that was just declared above.
::winapi::core::initonce user_input ::winapi::__init_user_input

package provide winapi 0.2
