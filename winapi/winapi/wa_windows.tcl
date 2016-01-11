package require winapi::core

namespace eval ::winapi {
    variable WINAPI
    variable log
}


# ::winapi::FindWindow -- Wrapper around FindWindow
#
#	This procedure finds a (toplevel) window that exactly matches
#	a class (optional) or title (optional).
#
# Arguments:
#	class	Class of window, can be empty
#	title	Title of window, can be empty
#
# Results:
#	Returns the handle of the window or 0
#
# Side Effects:
#	None.
proc ::winapi::FindWindow { class title } {
    if { [string length $class] == 0 && [string length $title] == 0} {
        __FindWindowTitleNone 0 0
    } elseif { [string length $class] == 0 } {
        __FindWindowTitle 0 $title
    } elseif { [string length $title] == 0 } {
        __FindWindowClass $class 0
    } else {
        __FindWindow $class $title
    }    
}


# ::winapi::FindWindowEx -- Wrapper around FindWindowEx
#
#	This procedure finds a children window that exactly matches
#	a class (optional) or title (optional).
#
# Arguments:
#	parent	Parent top window under which to look for window.
#	child	Handle of child window to start search for after.
#	class	Class of window, can be empty
#	title	Title of window, can be empty
#
# Results:
#	Returns the handle of the window or 0
#
# Side Effects:
#	None.
proc ::winapi::FindWindowEx { parent child class title } {
    variable WINAPI
    if { [string is true WINAPI(unicode)] } {
	set uniclass [binary format "A*" [encoding convertto unicode $class]]
	set unititle [binary format "A*" [encoding convertto unicode $title]]
    }
    if { [string length $class] == 0 && [string length $title] == 0} {
        __FindWindowExNone $parent $child 0 0
    } elseif { [string length $class] == 0 } {
	if { [string is true $WINAPI(unicode)] } {
	    __FindWindowExNone $parent $child 0 $unititle
	} else {
	    __FindWindowExTitle $parent $child 0 $title
	}
    } elseif { [string length $title] == 0 } {
	if { [string is true $WINAPI(unicode)] } {
	    __FindWindowExNone $parent $child $uniclass 0
	} else {
	    __FindWindowExClass $parent $child $class 0
	}
    } else {
	if { [string is true $WINAPI(unicode)] } {
	    __FindWindowExNone $parent $child $uniclass $unititle
	} else {
	    __FindWindowEx $parent $child $class $title
	}
    }    
}


# ::winapi::GetClassName -- Get window class name wrapper
#
#	This procedure extracts the class of a window and returns it
#
# Arguments:
#	w	Handle of window to get information from
#	bufsize	Max number of characters when asking for the class name
#
# Results:
#	Returns class of window.
#
# Side Effects:
#	None.
proc ::winapi::GetClassName { w { bufsize 1024 } } {
    variable WINAPI
    set buf [binary format x$bufsize]
    __GetClassName $w buf $bufsize
    binary scan $buf A* buf
    if { [string is true $WINAPI(unicode)] } {
	return [encoding convertfrom unicode $buf]
    } else {
	return $buf
    }
}


# ::winapi::GetWindowText -- Get window text
#
#	This procedure extracts the text of a window (usually title bar).
#
# Arguments:
#	w	Handle of window to get information from
#	bufsize	Max number of characters when asking for the class name
#
# Results:
#	Returns text of window.
#
# Side Effects:
#	None.
proc ::winapi::GetWindowText { w { bufsize 1024 } } {
    variable WINAPI
    set buf [binary format x$bufsize]
    __GetWindowText $w buf $bufsize
    binary scan $buf A* buf
    if { [string is true $WINAPI(unicode)] } {
	return [encoding convertfrom unicode $buf]
    } else {
	return $buf
    }
}


# ::winapi::GetWindowRect -- Get window rect
#
#	This procedure extracts the rectangle enclosing one window.
#
# Arguments:
#	w	Handle of window to get information from
#
# Results:
#	Returns a list formed of, respectively, the left, top, right
#	and bottom pixel position of the rectangle.
#
# Side Effects:
#	None.
proc ::winapi::GetWindowRect { w } {
    # Initialise a "RECT" structure, pass it to __GetWindowRect and
    # extract and return values.
    set buf [binary format x[::ffidl::info sizeof ::winapi::RECT]]
    __GetWindowRect $w buf
    binary scan $buf [::ffidl::info format ::winapi::RECT] \
	left top right bottom

    return [list $left $top $right $bottom]
}


# ::winapi::GetClientRect -- Get window rect
#
#	This procedure extracts the rectangle enclosing a window in
#	client coordinates.
#
# Arguments:
#	w	Handle of window to get information from
#
# Results:
#	Return a list form of, respectively, the left, top, right and
#	bottom pixel position of the rectangle. left and top always 0
#
# Side Effects:
#	None.
proc ::winapi::GetClientRect { w } {
    # Initialise a "RECT" structure, pass it to __GetClientRect and
    # extract and return values.
    set buf [binary format x[::ffidl::info sizeof ::winapi::RECT]]
    __GetClientRect $w buf
    binary scan $buf [::ffidl::info format ::winapi::RECT] \
	left top right bottom

    return [list $left $top $right $bottom]
}


# ::winapi::GetWindowModuleFileName -- Get Module File Name
#
#	The command retrieves the full path and file name of the
#	module associated with the specified window handle.
#
# Arguments:
#	w	Handle of window
#	bufsize	Max number of characters.
#
# Results:
#	Return the module file name
#
# Side Effects:
#	None.
proc ::winapi::GetWindowModuleFileName { w { bufsize 1024 } } {
    variable WINAPI
    set buf [binary format x$bufsize]
    set res [__GetWindowModuleFileName $w buf $bufsize]
    binary scan $buf A* buf
    if { [string is true $WINAPI(unicode)] } {
	return [encoding convertfrom unicode $buf]
    } else {
	return $buf
    }
}

# ::winapi::GetWindowPlacement -- Get window show state and minimised info
#
#	This procedure retrieves the show state and the restored,
#	minimized, and maximized positions of the specified window.
#
# Arguments:
#	w	Handle of window to get information from
#
# Results:
#	Return a list ready for an array set command with the
#	following keys: flags showCmd ptMinPosX ptMinPosY ptMaxPosX
#	ptMaxPosY rcNormalPosLeft rcNormalPosTop rcNormalPosRight
#	rcNormalPosBottom, where flags and showCmd are textual list
#
# Side Effects:
#	None.
proc ::winapi::GetWindowPlacement { w } {
    set buf [binary format x[::ffidl::info sizeof ::winapi::WINDOWPLACEMENT]]
    if { [__GetWindowPlacement $w buf] } {
	binary scan $buf [::ffidl::info format ::winapi::WINDOWPLACEMENT] \
	    len flags showCmd ptMinPosX ptMinPosY ptMaxPosX ptMaxPosY \
	    rcPosLeft rcPosTop rcPosRight rcPosBottom
	set flags_l [core::tflags $flags [list \
					  WPF_ASYNCWINDOWPLACEMENT 4\
					  WPF_RESTORETOMAXIMIZED 2 \
					  WPF_SETMINPOSITION 1]]
	set cmd [core::tflag $showCmd [list \
				       SW_HIDE             0 \
				       SW_MAXIMIZE         3 \
				       SW_MINIMIZE         6 \
				       SW_RESTORE          9 \
				       SW_SHOW             5 \
				       SW_SHOWMINIMIZED    2 \
				       SW_SHOWMAXIMIZED    3 \
				       SW_SHOWMINNOACTIVE  7 \
				       SW_SHOWNA           8 \
				       SW_SHOWNOACTIVATE   4 \
				       SW_SHOWNORMAL       1 \
				       SW_NORMAL           1 \
				       SW_SHOWDEFAULT	   10 \
				       SW_FORCEMINIMIZE    11 \
				       SW_MAX              11 \
				       SW_NORMALNA	   [expr {0xCC}]]]
	return [list flags "$flags_l" showCmd $cmd \
		    ptMinPosX $ptMinPosX ptMinPosY $ptMinPosY \
		    ptMaxPosX $ptMaxPosX ptMaxPosY $ptMaxPosY \
		    rcNormalPosLeft $rcPosLeft rcNormalPosTop $rcPosTop \
		    rcNormalPosRight $rcPosRight \
		    rcNormalPosBottom $rcPosBottom]
    }
    return ""
}


# ::winapi::SetWindowPlacement -- Set window show state and minimised info
#
#	This procedure sets the show state and the restored,
#	minimized, and maximized positions of the specified window.
#
# Arguments:
#	w	Handle of window to set information from
#	wndpl   Array describing the window placement, the recognised
#	        values are flags showCmd ptMinPosX ptMinPosY ptMaxPosX
#	        ptMaxPosY rcNormalPosLeft rcNormalPosTop rcNormalPosRight
#	        rcNormalPosBottom, where flags and showCmd are textual.
#	        Missing value will be default to current (GetWindowPlacment)
#
# Results:
#	Return boolean telling success.
#
# Side Effects:
#	None.
proc ::winapi::SetWindowPlacement { w wndpl } {
    array set placement [GetWindowPlacement $w]
    array set placement $wndpl
    set placement(flags) [core::flags $placement(flags) [list \
					  *ASYNCWINDOWPLACEMENT 4\
					  *RESTORETOMAXIMIZED 2 \
					  *SETMINPOSITION 1]]
    set placement(showCmd) [core::flag $placement(showCmd) [list \
				       *HIDE             0 \
				       *MAXIMIZE         3 \
				       *MINIMIZE         6 \
				       *RESTORE          9 \
				       *SHOW             5 \
				       *SHOWMINIMIZED    2 \
				       *SHOWMAXIMIZED    3 \
				       *SHOWMINNOACTIVE  7 \
				       *SHOWNA           8 \
				       *SHOWNOACTIVATE   4 \
				       *SHOWNORMAL       1 \
				       *NORMAL           1 \
				       *SHOWDEFAULT	   10 \
				       *FORCEMINIMIZE    11 \
				       *MAX              11 \
				       *NORMALNA	   [expr {0xCC}]]]

    set buf [binary format [::ffidl::info format ::winapi::WINDOWPLACEMENT] \
		 [::ffidl::info sizeof ::winapi::WINDOWPLACEMENT] \
		 $placement(flags) \
		 $placement(showCmd) \
		 $placement(ptMinPosX) \
		 $placement(ptMinPosY) \
		 $placement(ptMaxPosX) \
		 $placement(ptMaxPosY) \
		 $placement(rcNormalPosLeft) \
		 $placement(rcNormalPosTop) \
		 $placement(rcNormalPosRight) \
		 $placement(rcNormalPosBottom)]

    return [__SetWindowPlacement $w buf]
}


# ::winapi::ShowWindow -- Set window show state
#
#	This procedure sets the show state
#
# Arguments:
#	w	Handle of window to set information from
#	cmd	Any valid SW_ command (see win API).
#
# Results:
#	Return boolean telling success.
#
# Side Effects:
#	None.
proc ::winapi::ShowWindow { w cmd } {
    set cmd [core::flag $cmd [list \
			      *HIDE             0 \
			      *MAXIMIZE         3 \
			      *MINIMIZE         6 \
			      *RESTORE          9 \
			      *SHOW             5 \
			      *SHOWMINIMIZED    2 \
			      *SHOWMAXIMIZED    3 \
			      *SHOWMINNOACTIVE  7 \
			      *SHOWNA           8 \
			      *SHOWNOACTIVATE   4 \
			      *SHOWNORMAL       1 \
			      *NORMAL           1 \
			      *SHOWDEFAULT	   10 \
			      *FORCEMINIMIZE    11 \
			      *MAX              11 \
			      *NORMALNA	   [expr {0xCC}]]]
    __ShowWindow $w $cmd
}


# ::winapi::GetAncestor -- Get ancestor of a window
#
#	This procedure retrieves the handle to the ancestor of the
#	specified window
#
# Arguments:
#	w	Handle of window to get information for
#	flag	Any valid GA_ flag (see win API).
#
# Results:
#	Handle of the ancestor window
#
# Side Effects:
#	None.
proc ::winapi::GetAncestor { w flag } {
    set flag [core::flag $flag [list \
				*PARENT           1 \
				*ROOT             2 \
				*ROOTOWNER	  3]]
    __GetAncestor $w $flag
}


# ::winapi::SetWindowPos -- Set window size, position and z-order
#
#	This procedure changes the size, position, and Z order of a
#	child, pop-up, or top-level window. Child, pop-up, and
#	top-level windows are ordered according to their appearance on
#	the screen. The topmost window receives the highest rank and
#	is the first window in the Z order.
#
# Arguments:
#	w	Handle of window to set information from
#	w_after	Handle of the window to precede the positioned window
#	x	New X position
#	y	New Y position
#	cx	New width
#	cy	New height
#	f	Flags (see API doc)
#
# Results:
#	Return boolean telling success.
#
# Side Effects:
#	None.
proc ::winapi::SetWindowPos { w w_after {x -1} {y -1} {cx -1} {cy -1} {f ""}} {
    # Fix some decent default values so that we can skip passing
    # parameters sometimes.
    if { $f == "" } {
	if { $x < 0 && $y < 0 } {
	    lappend f SWP_NOMOVE
	}
	if { $cx < 0 && $cy < 0 } {
	    lappend f SWP_NOSIZE
	}
    }

    set w_after [core::flag $w_after [list \
				      *BOTTOM      1 \
				      *NOTOPMOST   -2 \
				      *TOPMOST     -1 \
				      *TOP         0 \
				      *MESSAGE     -3]]
    set f [core::flags $f [list \
			  *NOSIZE          [expr {0x0001}]\
			  *NOMOVE          [expr {0x0002}]\
			  *NOZORDER        [expr {0x0004}]\
			  *NOREDRAW        [expr {0x0008}]\
			  *NOACTIVATE      [expr {0x0010}]\
			  *FRAMECHANGED    [expr {0x0020}]\
			  *SHOWWINDOW      [expr {0x0040}]\
			  *HIDEWINDOW      [expr {0x0080}]\
			  *NOCOPYBITS      [expr {0x0100}]\
			  *NOOWNERZORDER   [expr {0x0200}]]]
    __SetWindowPos $w $w_after $x $y $cx $cy $f
}

	if { 0 } {
	set res(dwStyle) [core::tflags $res(dwStyle) \
			      [list \
				   WS_OVERLAPPEDWINDOW [expr {0x00CF0000}] \
				   WS_TILEDWINDOW   [expr {0x00CF0000}] \
				   WS_POPUPWINDOW   [expr {0x80880000}] \
				   WS_OVERLAPPED    [expr {0x00000000}] \
				   WS_POPUP         [expr {0x80000000}] \
				   WS_CHILD         [expr {0x40000000}] \
				   WS_MINIMIZE      [expr {0x20000000}] \
				   WS_VISIBLE       [expr {0x10000000}] \
				   WS_DISABLED      [expr {0x08000000}] \
				   WS_CLIPSIBLINGS  [expr {0x04000000}] \
				   WS_CLIPCHILDREN  [expr {0x02000000}] \
				   WS_MAXIMIZE      [expr {0x01000000}] \
				   WS_CAPTION       [expr {0x00C00000}] \
				   WS_BORDER        [expr {0x00800000}] \
				   WS_DLGFRAME      [expr {0x00400000}] \
				   WS_VSCROLL       [expr {0x00200000}] \
				   WS_HSCROLL       [expr {0x00100000}] \
				   WS_SYSMENU       [expr {0x00080000}] \
				   WS_THICKFRAME    [expr {0x00040000}] \
				   WS_GROUP         [expr {0x00020000}] \
				   WS_TABSTOP       [expr {0x00010000}] \
				   WS_MINIMIZEBOX   [expr {0x00020000}] \
				   WS_MAXIMIZEBOX   [expr {0x00010000}] \
				   WS_TILED         [expr {0x00000000}] \
				   WS_ICONIC        [expr {0x20000000}] \
				   WS_SIZEBOX       [expr {0x00040000}] \
				   WS_CHILDWINDOW   [expr {0x40000000}]]]
	}

# ::winapi::GetWindowInfo -- Get window information.
#
#	This procedure retrieves information about the specified window
#
# Arguments:
#	w	Handle of window to get information from
#
# Results:
#	Return a list ready for an array set command with the following keys.
#
# Side Effects:
#	None.
proc ::winapi::GetWindowInfo { w } {
    set buf [binary format x[::ffidl::info sizeof ::winapi::WINDOWINFO]]
    if { [__GetWindowInfo $w buf] } {
	array set res {}
	binary scan $buf [::ffidl::info format ::winapi::WINDOWINFO] \
	    len \
	    res(rcWindowLeft) res(rcWindowTop) \
	    res(rcWindowRight) res(rcWindowBottom) \
	    res(rcClientLeft) res(rcClientTop) \
	    res(rcClientRight) res(rcClientBottom) \
	    res(dwStyle) res(dwExStyle) res(dwWindowStatus) \
	    res(cxWindowBorders) res(cyWindowBorders) \
	    res(atomWindowType) res(wCreatorVersion)
	set res(dwStyle) [core::tflags $res(dwStyle) \
			      [list \
				   WS_OVERLAPPED    [expr {0x00000000}] \
				   WS_POPUP         [expr {0x80000000}] \
				   WS_CHILD         [expr {0x40000000}] \
				   WS_MINIMIZE      [expr {0x20000000}] \
				   WS_VISIBLE       [expr {0x10000000}] \
				   WS_DISABLED      [expr {0x08000000}] \
				   WS_CLIPSIBLINGS  [expr {0x04000000}] \
				   WS_CLIPCHILDREN  [expr {0x02000000}] \
				   WS_MAXIMIZE      [expr {0x01000000}] \
				   WS_CAPTION       [expr {0x00C00000}] \
				   WS_BORDER        [expr {0x00800000}] \
				   WS_DLGFRAME      [expr {0x00400000}] \
				   WS_VSCROLL       [expr {0x00200000}] \
				   WS_HSCROLL       [expr {0x00100000}] \
				   WS_SYSMENU       [expr {0x00080000}] \
				   WS_THICKFRAME    [expr {0x00040000}] \
				   WS_GROUP         [expr {0x00020000}] \
				   WS_TABSTOP       [expr {0x00010000}] \
				   WS_MINIMIZEBOX   [expr {0x00020000}] \
				   WS_MAXIMIZEBOX   [expr {0x00010000}]]]
	set res(dwExStyle) [core::tflags $res(dwExStyle) \
				[list \
				     WS_EX_DLGMODALFRAME  [expr {0x00000001}] \
				     WS_EX_DRAGDETECT     [expr {0x00000002}] \
				     WS_EX_NOPARENTNOTIFY [expr {0x00000004}] \
				     WS_EX_TOPMOST        [expr {0x00000008}] \
				     WS_EX_ACCEPTFILES    [expr {0x00000010}] \
				     WS_EX_TRANSPARENT    [expr {0x00000020}] \
				     WS_EX_MDICHILD       [expr {0x00000040}] \
				     WS_EX_TOOLWINDOW     [expr {0x00000080}] \
				     WS_EX_WINDOWEDGE     [expr {0x00000100}] \
				     WS_EX_CLIENTEDGE     [expr {0x00000200}] \
				     WS_EX_CONTEXTHELP    [expr {0x00000400}] \
				     WS_EX_RIGHT          [expr {0x00001000}] \
				     WS_EX_LEFT           [expr {0x00000000}] \
				     WS_EX_RTLREADING     [expr {0x00002000}] \
				     WS_EX_LTRREADING     [expr {0x00000000}] \
				     WS_EX_LEFTSCROLLBAR  [expr {0x00004000}] \
				     WS_EX_RIGHTSCROLLBAR [expr {0x00000000}] \
				     WS_EX_CONTROLPARENT  [expr {0x00010000}] \
				     WS_EX_STATICEDGE     [expr {0x00020000}] \
				     WS_EX_APPWINDOW      [expr {0x00040000}] \
				     WS_EX_LAYERED        [expr {0x00080000}] \
				     WS_EX_NOINHERITLAYOUT [expr {0x00100000}]\
				     WS_EX_LAYOUTRTL      [expr {0x00400000}] \
				     WS_EX_COMPOSITED     [expr {0x02000000}] \
				     WS_EX_NOACTIVATE     [expr {0x08000000}]]]
	return [array get res]
    }
    return ""
}


# ::winapi::GetWindowThreadProcessId -- Get thread & process id of window
#
#	The GetWindowThreadProcessId function retrieves the identifier
#	of the thread that created the specified window and the
#	identifier of the process that created the window.
#
# Arguments:
#	w	Handle of window
#
# Results:
#	Return a list formed of the process and thread id (in that
#	order) associated to the window.
#
# Side Effects:
#	None.
proc ::winapi::GetWindowThreadProcessId { w } {
    set buf [binary format x[::ffidl::info sizeof int]]
    set thid [__GetWindowThreadProcessId $w buf]
    binary scan $buf [::ffidl::info format int] pid

    return [list $pid $thid]
}


# ::winapi::GetGUIThreadInfo -- Get Window information for thread
#
#	Retrieves information about the active window or a specified
#	graphical user interface (GUI) thread.
#
# Arguments:
#	tid	Identifier of GUI thread
#
# Results:
#	Return a list ready for an array set command with the following key.
#
# Side Effects:
#	None.
proc ::winapi::GetGUIThreadInfo { tid } {
    variable log

    set buf [binary format \
		 "x[::ffidl::info sizeof ::winapi::GUITHREADINFO]@0i1" \
		 [::ffidl::info sizeof ::winapi::GUITHREADINFO]]
    if { [__GetGUIThreadInfo $tid buf] } {
	binary scan $buf [::ffidl::info format ::winapi::GUITHREADINFO] \
	    len \
	    info(flags) \
	    info(hwndActive) info(hwndFocus) info(hwndCapture) \
	    info(hwndMenuOwner) info(hwndMoveSize) info(hwndCaret) \
	    info(rcCaretLeft) info(rcCaretTop) \
	    info(rcCaretRight) info(rcCaretBottom)
	set info(flags) [core::tflags $info(flags) \
			     [list \
				  GUI_CARETBLINKING  [expr {0x00000001}] \
				  GUI_INMOVESIZE     [expr {0x00000002}] \
				  GUI_INMENUMODE     [expr {0x00000004}] \
				  GUI_SYSTEMMENUMODE [expr {0x00000008}] \
				  GUI_POPUPMENUMODE  [expr {0x00000010}] \
				  GUI_16BITTASK      [expr {0x00000020}]]]
	return [array get info]
    } else {
	${log}::warn "Could not call GetGUIThreadInfo $tid"
    }

    return [list]
}

# ::winapi::GetClassLong -- Get class info for window
#
#	The GetClassLong function retrieves the specified 32-bit
#	(long) value from the WNDCLASSEX structure associated with the
#	specified window
#
# Arguments:
#	w	Window handle
#	nIndex	Information to get (see MSDN)
#
# Results:
#	Return the requested 32-bit value, or zero on errors.
#
# Side Effects:
#	None.
proc ::winapi::GetClassLong { w nIndex } {
    variable WINAPI
    variable log

    set nIndex [core::flag \
		    [list \
			 *ATOM                      -32 \
			 *CBCLSEXTRA                -20 \
			 *CBWNDEXTRA                -18 \
			 *HBRBACKGROUND             -10 \
			 *HCURSOR                   -12 \
			 *HICON                     -14 \
			 *HICONSM                   -34 \
			 *HMODULE                   -16 \
			 *MENUNAME                  -8 \
			 *STYLE                     -26 \
			 *WNDPROC                   -24]]
    return [__GetClassLong $w $nIndex]
}


# ::winapi::GetClassWord -- Get class info for window
#
#	The GetClassWord function retrieves the specified 16-bit
#	(word) value from the WNDCLASS structure associated with the
#	specified window
#
# Arguments:
#	w	Window handle
#	nIndex	Information to get (see MSDN)
#
# Results:
#	Return the requested 16-bit value, or zero on errors.
#
# Side Effects:
#	None.
proc ::winapi::GetClassWord { w nIndex } {
    variable WINAPI
    variable log

    set nIndex [core::flag \
		    [list \
			 *ATOM                      -32 \
			 *HICONSM		    -34]]
    return [__GetClassWord $w $nIndex]
}


# ::winapi::GetClassLongPtr -- Get class info for window
#
#	The GetClassLong function retrieves the specified 32-bit
#	(long) value from the WNDCLASSEX structure associated with the
#	specified window.  If you are retrieving a pointer or a
#	handle, this function supersedes the GetClassLong
#	function. (Pointers and handles are 32 bits on 32-bit
#	Microsoft Windows and 64 bits on 64-bit Windows.) To write
#	code that is compatible with both 32-bit and 64-bit versions
#	of Windows, use GetClassLongPtr.
#
# Arguments:
#	w	Window handle
#	nIndex	Information to get (see MSDN)
#
# Results:
#	Return the requested 32-bit value, or zero on errors.
#
# Side Effects:
#	None.
proc ::winapi::GetClassLongPtr { w nIndex } {
    variable WINAPI
    variable log

    set nIndex [core::flag \
		    [list \
			 *ATOM                      -32 \
			 *CBCLSEXTRA                -20 \
			 *CBWNDEXTRA                -18 \
			 *STYLE                     -26 \
			 *MENUNAME                 -8 \
			 *HBRBACKGROUND            -10 \
			 *HCURSOR                  -12 \
			 *HICON                    -14 \
			 *HMODULE                  -16 \
			 *WNDPROC                  -24 \
			 *HICONSM                  -34]]

    return [__GetClassLongPtr $w $nIndex]
}


# ::winapi::GetWindowLong -- Get Window Information
#
#	This procedure retrieves information about the specified
#	window. The function also retrieves the 32-bit (long) value at
#	the specified offset into the extra window memory.
#
# Arguments:
#	whnd	Handle to the window (and the class it belongs to)
#	index	zero-based offset of the value to retrieve or GWL_ constants
#
# Results:
#	Returns the value of the information or an empty string on
#	error.  Window styles will be converted to lists of textual
#	constants.
#
# Side Effects:
#	None.
proc ::winapi::GetWindowLong { w index } {
    variable WINAPI
    variable log

    set index [core::flag $index \
		   [list \
			*EXSTYLE              -20 \
			*STYLE                -16 \
			*WNDPROC              -4 \
			*HINSTANCE            -6 \
			*HWNDPARENT           -8 \
			*ID                   -12 \
			*USERDATA             -21 \
			*DLGPROC              4 \
			*MSGRESULT            0 \
			*USER                 8]]
    set res [__GetWindowLong $w $index]
    if { $index == -20 } {
	# Convert to WS_EX constants when GWL_EXSTYLE was requested
	set res [core::tflags $res \
		     [list \
			  WS_EX_DLGMODALFRAME  [expr {0x00000001}] \
			  WS_EX_DRAGDETECT     [expr {0x00000002}] \
			  WS_EX_NOPARENTNOTIFY [expr {0x00000004}] \
			  WS_EX_TOPMOST        [expr {0x00000008}] \
			  WS_EX_ACCEPTFILES    [expr {0x00000010}] \
			  WS_EX_TRANSPARENT    [expr {0x00000020}] \
			  WS_EX_MDICHILD       [expr {0x00000040}] \
			  WS_EX_TOOLWINDOW     [expr {0x00000080}] \
			  WS_EX_WINDOWEDGE     [expr {0x00000100}] \
			  WS_EX_CLIENTEDGE     [expr {0x00000200}] \
			  WS_EX_CONTEXTHELP    [expr {0x00000400}] \
			  WS_EX_RIGHT          [expr {0x00001000}] \
			  WS_EX_LEFT           [expr {0x00000000}] \
			  WS_EX_RTLREADING     [expr {0x00002000}] \
			  WS_EX_LTRREADING     [expr {0x00000000}] \
			  WS_EX_LEFTSCROLLBAR  [expr {0x00004000}] \
			  WS_EX_RIGHTSCROLLBAR [expr {0x00000000}] \
			  WS_EX_CONTROLPARENT  [expr {0x00010000}] \
			  WS_EX_STATICEDGE     [expr {0x00020000}] \
			  WS_EX_APPWINDOW      [expr {0x00040000}] \
			  WS_EX_LAYERED        [expr {0x00080000}] \
			  WS_EX_NOINHERITLAYOUT [expr {0x00100000}]\
			  WS_EX_LAYOUTRTL      [expr {0x00400000}] \
			  WS_EX_COMPOSITED     [expr {0x02000000}] \
			  WS_EX_NOACTIVATE     [expr {0x08000000}]]]
    }
    if { $index == -16 } {
	# Convert to WS_ constants when GWL_STYLE was requested
	set res [core::tflags $res \
		     [list \
			  WS_OVERLAPPED    [expr {0x00000000}] \
			  WS_POPUP         [expr {0x80000000}] \
			  WS_CHILD         [expr {0x40000000}] \
			  WS_MINIMIZE      [expr {0x20000000}] \
			  WS_VISIBLE       [expr {0x10000000}] \
			  WS_DISABLED      [expr {0x08000000}] \
			  WS_CLIPSIBLINGS  [expr {0x04000000}] \
			  WS_CLIPCHILDREN  [expr {0x02000000}] \
			  WS_MAXIMIZE      [expr {0x01000000}] \
			  WS_CAPTION       [expr {0x00C00000}] \
			  WS_BORDER        [expr {0x00800000}] \
			  WS_DLGFRAME      [expr {0x00400000}] \
			  WS_VSCROLL       [expr {0x00200000}] \
			  WS_HSCROLL       [expr {0x00100000}] \
			  WS_SYSMENU       [expr {0x00080000}] \
			  WS_THICKFRAME    [expr {0x00040000}] \
			  WS_GROUP         [expr {0x00020000}] \
			  WS_TABSTOP       [expr {0x00010000}] \
			  WS_MINIMIZEBOX   [expr {0x00020000}] \
			  WS_MAXIMIZEBOX   [expr {0x00010000}]]]
    }
    return $res
}


# ::winapi::SetWindowLong -- Set window information
#
#	This procedure changes an attribute of the specified
#	window. The function also sets the 32-bit (long) value at the
#	specified offset into the extra window memory.
#
# Arguments:
#	whnd	Handle to the window (and indirectly the class it belongs to
#	index	Zero-based offset of the value to set or GWL_ constants
#	val	Replacement value
#
# Results:
#	1 on succes, 0 on failure.
#
# Side Effects:
#	None.
proc ::winapi::SetWindowLong { w index val } {
    variable WINAPI
    variable log

    set index [core::flag $index \
		   [list \
			*EXSTYLE              -20 \
			*STYLE                -16 \
			*WNDPROC              -4 \
			*HINSTANCE            -6 \
			*HWNDPARENT           -8 \
			*ID                   -12 \
			*USERDATA             -21 \
			*DLGPROC              4 \
			*MSGRESULT            0 \
			*USER                 8]]
    if { $index == -20 } {
	# Index to set is GWL_EXSTYLE, convert val from the list of
	# textual constants to integer value
	set val [core::flags $val \
		     [list \
			  *DLGMODALFRAME  [expr {0x00000001}] \
			  *DRAGDETECT     [expr {0x00000002}] \
			  *NOPARENTNOTIFY [expr {0x00000004}] \
			  *TOPMOST        [expr {0x00000008}] \
			  *ACCEPTFILES    [expr {0x00000010}] \
			  *TRANSPARENT    [expr {0x00000020}] \
			  *MDICHILD       [expr {0x00000040}] \
			  *TOOLWINDOW     [expr {0x00000080}] \
			  *WINDOWEDGE     [expr {0x00000100}] \
			  *CLIENTEDGE     [expr {0x00000200}] \
			  *CONTEXTHELP    [expr {0x00000400}] \
			  *RTLREADING     [expr {0x00002000}] \
			  *LTRREADING     [expr {0x00000000}] \
			  *LEFTSCROLLBAR  [expr {0x00004000}] \
			  *RIGHTSCROLLBAR [expr {0x00000000}] \
			  *CONTROLPARENT  [expr {0x00010000}] \
			  *STATICEDGE     [expr {0x00020000}] \
			  *APPWINDOW      [expr {0x00040000}] \
			  *LAYERED        [expr {0x00080000}] \
			  *NOINHERITLAYOUT [expr {0x00100000}]\
			  *LAYOUTRTL      [expr {0x00400000}] \
			  *COMPOSITED     [expr {0x02000000}] \
			  *RIGHT          [expr {0x00001000}] \
			  *LEFT           [expr {0x00000000}] \
			  *NOACTIVATE     [expr {0x08000000}]]]
    }
    
    if { $index == -16 } {
	# Index to set is GWL_STYLE, convert val from the list of
	# textual constants to integer value
	set val [core::flags $val \
		     [list \
			  *OVERLAPPEDWINDOW [expr {0x00CF0000}] \
			  *TILEDWINDOW   [expr {0x00CF0000}] \
			  *POPUPWINDOW   [expr {0x80880000}] \
			  *OVERLAPPED    [expr {0x00000000}] \
			  *POPUP         [expr {0x80000000}] \
			  *CHILD         [expr {0x40000000}] \
			  *MINIMIZE      [expr {0x20000000}] \
			  *VISIBLE       [expr {0x10000000}] \
			  *DISABLED      [expr {0x08000000}] \
			  *CLIPSIBLINGS  [expr {0x04000000}] \
			  *CLIPCHILDREN  [expr {0x02000000}] \
			  *MINIMIZEBOX   [expr {0x00020000}] \
			  *MAXIMIZEBOX   [expr {0x00010000}] \
			  *MAXIMIZE      [expr {0x01000000}] \
			  *CAPTION       [expr {0x00C00000}] \
			  *BORDER        [expr {0x00800000}] \
			  *DLGFRAME      [expr {0x00400000}] \
			  *VSCROLL       [expr {0x00200000}] \
			  *HSCROLL       [expr {0x00100000}] \
			  *SYSMENU       [expr {0x00080000}] \
			  *THICKFRAME    [expr {0x00040000}] \
			  *GROUP         [expr {0x00020000}] \
			  *TABSTOP       [expr {0x00010000}] \
			  *TILED         [expr {0x00000000}] \
			  *ICONIC        [expr {0x20000000}] \
			  *SIZEBOX       [expr {0x00040000}] \
			  *CHILDWINDOW   [expr {0x40000000}]]]
    }
    return [__SetWindowLong $w $index $val]
}


# ::winapi::SetLayeredWindowAttributes -- Set layered attributes
#
#	This procedure sets the opacity and transparency color key of
#	a layered window.
#
# Arguments:
#	w	Handle to the *layered* window
#	color	Color for the tranparency color key, integer or RGB triplet
#	alpha	Opacity of window: 0=tranparent, 255=opaque
#	flags	What to change (LWA_COLORKEY LWA_ALPHA)
#
# Results:
#	Non-zero on success, 0 on failure
#
# Side Effects:
#	None.
proc ::winapi::SetLayeredWindowAttributes { w color alpha flags } {
    set flags [core::flags $flags \
		   [list \
			*COLORKEY   1 \
			*ALPHA      2]]
    if { [llength $color] == 3 } {
	foreach {r g b} $color break
	set color [expr ($r & 0xFF) | (($g & 0xFF)<<8) | (($b & 0xFF)<<16)]
    }
    return [__SetLayeredWindowAttributes $w $color $alpha $flags]
}


# ::winapi::GetLayeredWindowAttributes -- Get layered attributes
#
#	This procedure retrieves the opacity and transparency color
#	key of a layered window.
#
# Arguments:
#	w	Identifier of the window
#
# Results:
#	Empty list on error, or a list with the color key followed by
#	the transparency value. The color key is itself a list of the
#	Red green and blue values or the triplet.
#
# Side Effects:
#	None.
proc ::winapi::GetLayeredWindowAttributes { w } {
    set flags [core::flags [list LWA_COLORKEY LWA_ALPHA] \
		   [list \
			*COLORKEY   1 \
			*ALPHA      2]]
    set bufcolor [binary format "x[::ffidl::info sizeof ::winapi::COLORREF]"]
    set bufalpha [binary format "x[::ffidl::info sizeof ::winapi::BYTE]"]
    if { [__GetLayeredWindowAttributes $w bufcolor bufalpha $flags] } {
	binary scan $bufcolor [::ffidl::info format ::winapi::COLORREF] color
	binary scan $bufalpha [::ffidl::info format ::winapi::BYTE] alpha
	set r [expr ($color & 0xFF)]
	set g [expr ($color & 0xFF00)>>8]
	set b [expr ($color & 0xFF0000)>>16]
	
	return [list [list $r $g $b] $alpha]
    }
    return [list]
}


proc ::winapi::__init_windows { } {
    variable WINAPI
    variable log
    
    # Local type defs
    ::ffidl::typedef ::winapi::WINDOWPLACEMENT \
	::winapi::UINT ::winapi::UINT ::winapi::UINT \
	::winapi::POINT ::winapi::POINT ::winapi::RECT
    ::ffidl::typedef ::winapi::WINDOWINFO \
	::winapi::DWORD ::winapi::RECT ::winapi::RECT \
	::winapi::DWORD ::winapi::DWORD ::winapi::DWORD \
	::winapi::UINT ::winapi::UINT \
	::winapi::ATOM ::winapi::WORD
    ::ffidl::typedef ::winapi::GUITHREADINFO \
	::winapi::DWORD ::winapi::DWORD \
	::winapi::HWND ::winapi::HWND ::winapi::HWND \
	::winapi::HWND ::winapi::HWND ::winapi::HWND \
	::winapi::RECT
    ::ffidl::typedef ::winapi::COLORREF ::winapi::DWORD

    # FindWindow in all its forms to support both empty and non-empty strings
    core::api __FindWindow { pointer-utf8 pointer-utf8 } \
	::winapi::HWND FindWindow
    core::api __FindWindowTitle { ::winapi::LPCTSTR pointer-utf8 } \
	::winapi::HWND FindWindow
    core::api __FindWindowClass { pointer-utf8 ::winapi::LPCTSTR } \
	::winapi::HWND FindWindow
    core::api __FindWindowNone { ::winapi::LPCTSTR ::winapi::LPCTSTR } \
	::winapi::HWND FindWindow

    # FindWindowEx in all its forms to support both empty and non-empty strings
    core::api __FindWindowEx \
	{ ::winapi::HWND ::winapi::HWND pointer-utf8 pointer-utf8 } \
	::winapi::HWND FindWindowEx
    core::api __FindWindowExTitle \
	{ ::winapi::HWND ::winapi::HWND ::winapi::LPCTSTR pointer-utf8 } \
	::winapi::HWND FindWindowEx
    core::api __FindWindowExClass \
	{ ::winapi::HWND ::winapi::HWND pointer-utf8 ::winapi::LPCTSTR } \
	::winapi::HWND FindWindowEx
    core::api __FindWindowExNone \
	{ ::winapi::HWND ::winapi::HWND ::winapi::LPCTSTR ::winapi::LPCTSTR } \
	::winapi::HWND FindWindowEx

    core::api GetDesktopWindow {} ::winapi::HWND
    core::api GetForegroundWindow {} ::winapi::HWND
    core::api SetForegroundWindow {::winapi::HWND} ::winapi::BOOL
    core::api GetWindow { ::winapi::HWND ::winapi::UINT } ::winapi::HWND
    core::api __GetWindowText {::winapi::HWND pointer-var int} int
    core::api __GetWindowPlacement {::winapi::HWND pointer-var} ::winapi::BOOL
    core::api __SetWindowPlacement {::winapi::HWND pointer-var} ::winapi::BOOL
    core::api __SetWindowPos \
	{::winapi::HWND ::winapi::HWND int int int int ::winapi::UINT} \
	::winapi::BOOL
    core::api __ShowWindow {::winapi::HWND int} ::winapi::BOOL
    core::api MoveWindow { ::winapi::HWND int int int int ::winapi::BOOL } \
	::winapi::BOOL
    core::api OpenIcon { ::winapi::HWND } ::winapi::BOOL
    core::api __GetWindowInfo { ::winapi::HWND pointer-var } ::winapi::BOOL
    core::api BringWindowToTop { ::winapi::HWND } ::winapi::BOOL
    core::api GetTopWindow { ::winapi::HWND } ::winapi::HWND
    core::api SwitchToThisWindow { ::winapi::HWND ::winapi::BOOL } void
    core::api __GetAncestor { ::winapi::HWND ::winapi::UINT } ::winapi::HWND
    core::api GetParent { ::winapi::HWND } ::winapi::HWND
    core::api IsWindow { ::winapi::HWND } ::winapi::BOOL
    core::api IsWindowEnabled { ::winapi::HWND } ::winapi::BOOL
    core::api IsWindowVisible { ::winapi::HWND } ::winapi::BOOL
    core::api CloseWindow { ::winapi::HWND } ::winapi::BOOL
    core::api DestroyWindow { ::winapi::HWND } ::winapi::BOOL
    core::api __GetWindowThreadProcessId { ::winapi::HWND pointer-var } \
	::winapi::DWORD
    core::api __GetGUIThreadInfo { ::winapi::DWORD pointer-var } ::winapi::BOOL
    core::api IsGUIThread { ::winapi::BOOL } ::winapi::BOOL
    core::api ShowOwnedPopups { ::winapi::HWND ::winapi::BOOL } ::winapi::BOOL
    core::api __GetWindowModuleFileName \
	{ ::winapi::HWND pointer-var ::winapi::UINT } ::winapi::UINT
    core::api __SetLayeredWindowAttributes \
	{::winapi::HWND ::winapi::COLORREF ::winapi::BYTE ::winapi::DWORD} \
	::winapi::BOOL
    core::api __GetLayeredWindowAttributes \
	{::winapi::HWND pointer-var pointer-var ::winapi::DWORD} \
	::winapi::BOOL

    core::api __GetWindowRect { ::winapi::HWND pointer-var } ::winapi::BOOL
    core::api __GetClientRect { ::winapi::HWND pointer-var } ::winapi::BOOL

    # Window Classes
    core::api __GetClassLong {::winapi::HWND int} ::winapi::DWORD
    core::api __GetClassWord {::winapi::HWND int} ::winapi::WORD
    #core::api __GetClassLongPtr {::winapi::HWND int} ::winapi::ULONG_PTR
    core::api __GetClassName {::winapi::HWND pointer-var int} int
    core::api __SetWindowLong {::winapi::HWND int long} ::winapi::BOOL
    core::api __GetWindowLong {::winapi::HWND int} long
    
    return 1
}

# Now automatically initialises this module, once and only once
# through calling the __init procedure that was just declared above.
::winapi::core::initonce windows ::winapi::__init_windows

package provide winapi 0.2
