package require winapi::core

namespace eval ::winapi {
    variable WINAPI
    variable log
}

# ::winapi::MapWindowPoints -- Converts between coordinate systems
#
#	The MapWindowPoints function converts (maps) a set of points
#	from a coordinate space relative to one window to a coordinate
#	space relative to another window.
#
# Arguments:
#	hwndsrc	Handle to source window
#	hwnddst	Handle to destination window
#	points	List of coordinates of points to convert.
#
# Results:
#	Return the list of converted coordinates.
#
# Side Effects:
#	None.
proc ::winapi::MapWindowPoints { hwndsrc hwnddst points } {
    variable log

    set nbpoints [llength $points]
    if { ($nbpoints / 2)*2 != $nbpoints } {
	${log}::warn "Odd number of points passed to MapWindowPoints"
	return [list]
    }

    # Fill in incoming point information.
    set size [expr [::ffidl::info sizeof ::winapi::POINT] * $nbpoints]
    set buf [binary format x$size]
    set i 0
    set fmt ""
    set args [list]
    foreach {x y} $points {
	append fmt [format "@%d%s" \
		     [expr [::ffidl::info alignof ::winapi::POINT]*$i] \
		     [::ffidl::info format ::winapi::POINT]]
	lappend args $x $y
	incr i
    }
    set buf [eval binary format $fmt $args]

    set res [list]
    if { [__MapWindowPoints $hwndsrc $hwnddst buf $nbpoints] } {
	for { set i 0 } { $i < $nbpoints } { incr i } {
	    set fmt [format "@%d%s" \
			 [expr [::ffidl::info alignof ::winapi::POINT]*$i] \
			 [::ffidl::info format ::winapi::POINT]]
	    binary scan $buf $fmt x y
	    lappend res $x $y
	}
    } else {
	${log}::warn "Could not map window point"
    }
    return $res
}


# ::winapi::RealChildWindowFromPoint -- Get child window at point
#
#	The RealChildWindowFromPoint function retrieves a handle to
#	the child window at the specified point. The search is
#	restricted to immediate child windows; grandchildren and
#	deeper descendant windows are not searched.
#
# Arguments:
#	w	Handle to parent window
#	x	X coordinate of point
#	y	Y coordinate of point
#
# Results:
#	Handle of window.
#
# Side Effects:
#	None.
proc ::winapi::RealChildWindowFromPoint { w x y } {
    set buf [binary format [::ffidl::info format ::winapi::POINT] $x $y]
    return [__RealChildWindowFromPoint $w buf]
}


# ::winapi::ChildWindowFromPoint -- Get child window at point
#
#	The ChildWindowFromPoint function retrieves a handle to
#	the child window at the specified point. The search is
#	restricted to immediate child windows; grandchildren and
#	deeper descendant windows are not searched.
#
# Arguments:
#	w	Handle to parent window
#	x	X coordinate of point
#	y	Y coordinate of point
#
# Results:
#	Handle of window.
#
# Side Effects:
#	None.
proc ::winapi::ChildWindowFromPoint { w x y } {
    set buf [binary format [::ffidl::info format ::winapi::POINT] $x $y]
    return [__ChildWindowFromPoint $w buf]
}


# ::winapi::ScreenToClient -- Convert between coordinate systems
#
#	The ScreenToClient function converts the screen coordinates of
#	a specified point on the screen to client-area coordinates.
#
# Arguments:
#	w	Handle to window
#	x	X screen coordinates
#	y	X screen coordinates
#
# Results:
#	The coordinates of the point in client coordinates or empty list.
#
# Side Effects:
#	None.
proc ::winapi::ScreenToClient { w x y } {
    set buf [binary format [::ffidl::info format ::winapi::POINT] $x $y]
    if { [__ScreenToClient $w buf] } {
	binary scan $buf [::ffidl::info format ::winapi::POINT] cx cy
	return [list $cx $cy]
    }
    return [list]
}


# ::winapi::ClientToScreen -- Convert between coordinate systems
#
#	The ClientToScreen function converts the client-area
#	coordinates of a specified point to screen coordinates.
#
# Arguments:
#	w	Handle to window
#	x	X screen coordinates
#	y	X screen coordinates
#
# Results:
#	The coordinates of the point in screen coordinates or empty list.
#
# Side Effects:
#	None.
proc ::winapi::ClientToScreen { w x y } {
    set buf [binary format [::ffidl::info format ::winapi::POINT] $x $y]
    if { [__ClientToScreen $w buf] } {
	binary scan $buf [::ffidl::info format ::winapi::POINT] cx cy
	return [list $cx $cy]
    }
    return [list]
}


proc ::winapi::__init_gdi { } {
    variable WINAPI
    variable log
    
    # Local type defs

    # GDI
    core::api __MapWindowPoints \
	{ ::winapi::HWND ::winapi::HWND pointer-var ::winapi::UINT } int
    core::api __ScreenToClient { ::winapi::HWND pointer-var } ::winapi::BOOL
    core::api __ClientToScreen { ::winapi::HWND pointer-var } ::winapi::BOOL
    core::api __RealChildWindowFromPoint { ::winapi::HWND pointer-var } \
	::winapi::HWND
    core::api __ChildWindowFromPoint { ::winapi::HWND pointer-var } \
	::winapi::HWND

    return 1
}

# Now automatically initialises this module, once and only once
# through calling the __init procedure that was just declared above.
::winapi::core::initonce gdi ::winapi::__init_gdi

package provide winapi 0.2
