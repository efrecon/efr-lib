# winop.tcl -- Unified window operations
#
#	Unified window operations so that we will be able to see Tk
#	and Windows windows identically from the outside.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.4
package require Tk
package require winapix
package require logger

namespace eval ::winop {
    variable WOP
    if { ! [info exists WOP] } {
	array set WOP {
	    loglevel          warn
	    idgene            0
	    maxreceivers      -1
	    wins              ""
	    dft_ks_name       "keysym.map"
	    -dclick_precision 10
	    -clickwholetree   off
	}
	variable log [::logger::init [string trimleft [namespace current] ::]]
	variable libdir [file dirname [file normalize [info script]]]
	${log}::setlevel $WOP(loglevel)
	array set KeySymDB {}
    }
    namespace export new loglevel config defaults capture
}


# ::winop::loglevel -- Set/Get current log level.
#
#	Set and/or get the current log level for this library.
#
# Arguments:
#	loglvl	New loglevel
#
# Results:
#	Return the current log level
#
# Side Effects:
#	None.
proc ::winop::loglevel { { loglvl "" } } {
    variable WOP
    variable log

    if { $loglvl != "" } {
	if { [catch "${log}::setlevel $loglvl"] == 0 } {
	    set WOP(loglevel) $loglvl
	}
    }

    return $WOP(loglevel)
}


# ::winop::__trigger -- Trigger necessary callbacks
#
#	This command relays actions that occur within a window, into
#	external callers.  Basically, it calls back all matching
#	callbacks, which implements some sort of event model.
#
# Arguments:
#	whnd	Handle of the window (could be a Tk window name)
#	action	Action that occurs (event!)
#	args	Further argument definition for the event.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winop::__trigger { whnd action args } {
    variable WOP
    variable log

    set id [__init $whnd]
    if { $id ne "" } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window

	# Call all callbacks that have registered for matching actions.
	if { [array names Window callbacks] ne "" } {
	    foreach {ptn cb} $Window(callbacks) {
		if { [string match $ptn $action] } {
		    if { [catch {eval $cb $whnd $action $args} res] } {
			${log}::warn \
			    "Error when invoking $action callback $cb: $res"
		    }
		}
	    }
	}
    }
}


# ::winop::__find -- Find a window
#
#	This procedure finds a window through our DB.
#
# Arguments:
#	val	Value of the key to find
#	key	Which key to find with
#
# Results:
#	Returns the identifier of the window
#
# Side Effects:
#	None.
proc ::winop::__find { val { key id } } {
    variable WOP
    variable log

    foreach id $WOP(wins) {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window

	if { [array names Window $key] ne "" && $Window($key) == $val } {
	    return $id
	}
    }
    
    return ""
}


# ::winop::__ks_read -- Read in keysym database
#
#	This procedure appends to the current keysym database the
#	content of the file.  This file is in the "map" format, which
#	comes from the xterm source distribution.
#
# Arguments:
#	fname	Full path to file, empty to read default
#
# Results:
#	Return the number of keysym entries that were created, a
#	negative number on error.
#
# Side Effects:
#	None.
proc ::winop::__ks_read { { fname "" } } {
    variable WOP
    variable log
    variable libdir
    variable KeySymDB

    if { $fname eq "" } {
	set fname [file join $libdir $WOP(dft_ks_name)]
    }

    set nbread -1
    ${log}::info "Reading keysym database from '$fname'"
    if { [catch {open $fname} fd] } {
	${log}::warn "Could not read keysym database from '$fname': $fd"
    } else {
	set nbread 0
	while { ! [eof $fd] } {
	    set line [string trim [gets $fd]]
	    if { $line ne "" } {
		set firstchar [string index $line 0]
		if { [string first $firstchar "\#!;"] < 0 } {
		    set keysym_d [lindex $line 0]
		    set unicode_d [lindex $line 1]
		    set keysym_s [lindex $line 3]
		    
		    if { $unicode_d ne "U0000" } {
			set str [subst [string map {U \\u} $unicode_d]]
			set val [expr [string map {U 0x} $unicode_d]]
			set KeySymDB($keysym_s) $val
			incr nbread
			if { 0 } {
			    ${log}::debug \
				"Added $keysym_s -> $unicode_d ($str)\
                                 to keysym database"
			}
		    }
		}
	    }
	}
	close $fd
    }

    return $nbread
}


# ::winop::__init -- Initialise window state
#
#	This procedure installs the context for one of the window
#	abstractions that is passed as a parameter.  The procedure
#	makes differences between raw windows and Tk windows.
#
# Arguments:
#	whnd	Handle of the window (could be a Tk window name)
#
# Results:
#	Return the internal identifier for the window
#
# Side Effects:
#	None.
proc ::winop::__init { whnd } {
    variable WOP
    variable log
    variable KeySymDB

    # Read in keysym database once for all
    if { [llength [array names KeySymDB]] == 0 } {
	__ks_read
    }

    # Guess if the handle corresponds to a Windows handle
    set windows_hnd ""
    if { [string is integer $whnd] && [::winapi::IsWindow $whnd] } {
	set windows_hnd $whnd
    }
    if { $windows_hnd eq "" && [regexp {^([0-9a-fA-F])+$} $whnd] } {
	set windows_hnd [expr 0x$whnd]
    }
    if { $windows_hnd eq "" && [regexp {^0x([0-9a-fA-F])+$} $whnd] } {
	set windows_hnd [expr $whnd]
    }

    # Store necessary data in the local context for windows that are
    # new.  Do nothing for others.
    if { $windows_hnd ne "" } {
	set id [__find $windows_hnd whnd]
	if { $id eq "" } {
	    set id [incr WOP(idgene)]
	    set varname "::winop::Window_$id"
	    upvar \#0 $varname Window
	    set Window(whnd) $windows_hnd
	    set Window(type) WINDOWS
	    set Window(hints) [list]
	    set Window(callbacks) [list]
	    foreach btn [list "L" "M" "R"] {
		set Window(history_WM_${btn}BUTTONDOWN) [list]
		set Window(history_WM_${btn}BUTTONUP) [list]
	    }

	    lappend WOP(wins) $id
	}

	return $id
    } else {
	if { [regexp {^(\.\w+)+$} $whnd] } {
	    if { [winfo exists $whnd] } {
		set id [__find $whnd widget]
		if { $id eq "" } {
		    set id [incr WOP(idgene)]
		    set varname "::winop::Window_$id"
		    upvar \#0 $varname Window
		    set Window(whnd) [expr [winfo id $whnd]]
		    set Window(type) TK
		    set Window(hints) [list]
		    set Window(callbacks) [list]
		    set Window(widget) $whnd
		    
		    lappend WOP(wins) $id
		}
		
		return $id
	    }
	}
    }

    # Return an empty string on failures.
    return ""
}


# ::winop::handle -- Return raw handle of window
#
#	This procedure gets the raw handle of a window, whichever the
#	handle of the window is passed.
#
# Arguments:
#	whnd	Raw handle (as an integer or in hex) or Tk window name
#
# Results:
#	Return the raw handle or an empty string
#
# Side Effects:
#	None.
proc ::winop::handle { whnd } {
    variable WOP
    variable log

    set id [__init $whnd]
    if { $id ne "" } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window
	
	return $Window(whnd)
    }

    return ""
}


# ::winop::exists -- Check if window exists
#
#	This procedure checks if a window exists.
#
# Arguments:
#	whnd	Raw handle (as an integer or in hex) or Tk window name
#
# Results:
#	Return a true number on success, 0 otherwise
#
# Side Effects:
#	None.
proc ::winop::exists { whnd } {
    variable WOP
    variable log

    set id [__init $whnd]
    if { $id ne "" } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window

	switch -- $Window(type) {
	    "TK" { return [winfo exists $Window(widget)] }
	    "WINDOWS" { return [::winapi::IsWindow $Window(whnd)] }
	}
    }

    return 0
}


# ::winop::title -- Fetch window title
#
#	This procedure actively fetches the title of a window.
#
# Arguments:
#	whnd	Raw handle (as an integer or in hex) or Tk window name
#
# Results:
#	Return the window title or an empty string.
#
# Side Effects:
#	None.
proc ::winop::title { whnd } {
    variable WOP
    variable log

    set id [__init $whnd]
    if { $id ne "" && [exists $whnd] } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window

	switch -- $Window(type) {
	    "TK" { return [wm title $Window(widget)] }
	    "WINDOWS" { return [::winapi::GetWindowText $Window(whnd)] }
	}
    }

    return ""
}


# ::winop::visible -- Determines if window is visible
#
#	This procedure detects if a window is visible or not.
#
# Arguments:
#	whnd	Raw handle (as an integer or in hex) or Tk window name
#
# Results:
#	Return a true number if window is visible, 0 otherwise.
#
# Side Effects:
#	None.
proc ::winop::visible { whnd } {
    variable WOP
    variable log

    set id [__init $whnd]
    if { $id ne "" && [exists $whnd] } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window

	switch -- $Window(type) {
	    "TK" { return [winfo visible $Window(widget)] }
	    "WINDOWS" {
		set visibility 0
		array set winfo [::winapi::GetWindowInfo $w]
		if { [lsearch $winfo(dwStyle) WS_VISIBLE] >= 0 } {
		    set c_width \
			[expr $winfo(rcClientRight) - $winfo(rcClientLeft)]
		    set c_height \
			[expr $winfo(rcClientBottom) - $winfo(rcClientTop)]
		    if { $c_width > 0 && $c_height > 0 } {
			set visibility 1
		    }
		}
		return $visibility
	    }
	}
    }

    return 0
}


# ::winop::activation -- Activate/Deactivate windows
#
#	This procedure simulates the appropriate events when window
#	are activated (entered) or deactivated (leaved).
#
# Arguments:
#	whnd	Raw handle (as an integer or in hex) or Tk window name
#	state	Activation state (on or off)
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winop::activation { whnd state } {
    variable WOP
    variable log

    set id [__init $whnd]
    if { $id ne "" && [exists $whnd] } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window

	switch -- $Window(type) {
	    "TK" {
		if { [string is true $state] } {
		    event generate $Window(widget) <Enter>
		} else {
		    event generate $Window(widget) <Leave>
		}
	    }
	    "WINDOWS" {
		if { [string is true $state]} {
		    set ht [::winapi::core::flag HTCLIENT \
				[list \
				     HTERROR                  -2 \
				     HTTRANSPARENT            -1 \
				     HTNOWHERE                0 \
				     HTCLIENT                 1 \
				     HTCAPTION                2 \
				     HTSYSMENU                3 \
				     HTGROWBOX                4 \
				     HTSIZE                   4 \
				     HTMENU                   5 \
				     HTHSCROLL                6 \
				     HTVSCROLL                7 \
				     HTMINBUTTON              8 \
				     HTMAXBUTTON              9 \
				     HTREDUCE                 8 \
				     HTZOOM                   9 \
				     HTLEFT                   10 \
				     HTSIZEFIRST              10 \
				     HTRIGHT                  11 \
				     HTTOP                    12 \
				     HTTOPLEFT                13 \
				     HTTOPRIGHT               14 \
				     HTBOTTOM                 15 \
				     HTBOTTOMLEFT             16 \
				     HTBOTTOMRIGHT            17 \
				     HTSIZELAST               17 \
				     HTBORDER                 18 \
				     HTOBJECT                 19 \
				     HTCLOSE                  20 \
				     HTHELP                   21]]
		    set msg [::winapi::core::flag WM_MOUSEMOVE \
				 [list \
				      *MOUSEMOVE            [expr 0x200] \
				      *LBUTTONDOWN          [expr 0x201] \
				      *LBUTTONUP            [expr 0x202] \
				      *LBUTTONDBLCLK        [expr 0x203] \
				      *RBUTTONDOWN          [expr 0x204] \
				      *RBUTTONUP            [expr 0x205] \
				      *RBUTTONDBLCLK        [expr 0x206] \
				      *MBUTTONDOWN          [expr 0x207] \
				      *MBUTTONUP            [expr 0x208] \
				      *MBUTTONDBLCLK        [expr 0x209] \
				      *MOUSEWHEEL           [expr 0x20a] \
				      *XBUTTONDOWN          [expr 0x20b] \
				      *XBUTTONUP            [expr 0x20c] \
				      *XBUTTONDBLCLK        [expr 0x20d]]]
		    
		    ::winapi::SendMessage $Window(whnd) WM_MOUSEACTIVATE \
			$Window(whnd) \
			[::winapi::core::makelparam $ht $msg] 
		}
		if { [string is true $state] } {
		    set activation "WA_ACTIVE"
		    set focus "WM_SETFOCUS"
		    set tid [::winapi::GetCurrentThreadId]
		} else {
		    set activation "WA_INACTIVE"
		    set focus "WM_KILLFOCUS"
		    set tid [lindex \
				 [::winapi::GetWindowThreadProcessId \
				      $Window(whnd)] 1]
		}
		set a [::winapi::core::flag $activation \
			   [list \
				WA_ACTIVE           1 \
				WA_CLICKACTIVE      2 \
				WA_INACTIVE         0]]
		set wparam [::winapi::core::makewparam $a 0]
		if { [string is true $state] } {
		    ::winapi::SendMessage $Window(whnd) WM_ACTIVATE $wparam 0
		    ::winapi::SendMessage $Window(whnd) WM_ACTIVATEAPP 1 $tid
		    ::winapi::SendMessage $Window(whnd) WM_SETFOCUS 0 0
		} else {
		    ::winapi::SendMessage $Window(whnd) WM_KILLFOCUS 0 0
		    ::winapi::SendMessage $Window(whnd) WM_ACTIVATEAPP 0 $tid
		    ::winapi::SendMessage $Window(whnd) WM_ACTIVATE $wparam 0
		}
	    }
	}
    }
}

# ::winop::alpha -- Get/Set alpha transparency of window
#
#	This procedure gets or sets the alpha transparency of a main
#	top-level window at the OS level.
#
# Arguments:
#	whnd	Raw handle (as an integer or in hex) or Tk window name
#	alpha	New alpha value (empty to get value) 0=transparent, 100=opaque 
#
# Results:
#	Return the current alpha value of the window.
#
# Side Effects:
#	None.
proc ::winop::alpha { whnd { alpha "" } } {
    variable WOP
    variable log

    set id [__init $whnd]
    if { $id ne "" && [exists $whnd] } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window

	switch -- $Window(type) {
	    "TK" {
		if { $alpha eq "" } {
		    if { [catch {wm attributes $Window(widget) -alpha} val] } {
			${log}::warn "Could not get alpha for window: $val"
			set alpha 100
		    } else {
			set alpha [expr $val * 100]
		    }
		    __trigger $whnd AlphaGet $alpha
		    return $alpha
		} else {
		    if { $alpha < 0 } { set alpha 0 }
		    if { $alpha > 100 } { set alpha 100 }
		    set val [expr $alpha / 100.0]
		    if { [catch {wm attributes $Window(widget) \
				     -alpha $val} err] } {
			${log}::warn "Could not set the alpha of\
                                      $Window(widget) to $val: $err"
		    }
		    __trigger $whnd AlphaSet $alpha
		    return $alpha
		}
	    }
	    "WINDOWS" {
		set whnd $Window(whnd)
		set styles [::winapi::GetWindowLong $whnd GWL_EXSTYLE]
		if { $alpha eq "" } {
		    if { [lsearch $styles WS_EX_LAYERED] >= 0 } {
			set attr [::winapi::GetLayeredWindowAttributes $whnd]
			if { [llength $attr] > 0 } {
			    foreach {c a} $attr break
			    if { $a eq "" } {
				${log}::warn "Could not get alpha for window"
				set alpha 100
			    } else {
				set alpha [expr round((double($alpha)*100)/255)]
			    }
			} else {
			    set alpha 100
			}
		    } else {
			set alpha 100
		    }
		    __trigger $whnd AlphaGet $alpha
		    return $alpha
		} else {
		    if { $alpha < 0 } { set alpha 0 }
		    if { $alpha > 100 } { set alpha 100 }
		    if { [lsearch $styles WS_EX_LAYERED] < 0 } {
			${log}::debug "Forcing $whnd to be a layered window"
			lappend styles WS_EX_LAYERED
			if { ! [:::winapi::SetWindowLong $whnd \
				    GWL_EXSTYLE $styles] } {
			    ${log}::warn \
				"Failed forcing $whnd to a layered window"
			}
		    }
		    set walpha [expr int(double($alpha)*255/100)]
		    ::winapi::SetLayeredWindowAttributes $whnd 0 $walpha \
			LWA_ALPHA
		    __trigger $whnd AlphaSet $alpha
		    return $alpha
		}
	    }
	}
    }
    return 100
}


# ::winop::geometry -- Get/set geometry
#
#	This procedure gets or sets the geometry of a main top-level
#	window
#
# Arguments:
#	whnd	Raw handle (as an integer or in hex) or Tk window name
#	geo	Tk-style geometry (empty to get value)
#
# Results:
#	Return the current geometry
#
# Side Effects:
#	None.
proc ::winop::geometry { whnd { geo "" } } {
    variable WOP
    variable log

    set id [__init $whnd]
    if { $id ne "" && [exists $whnd] } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window
	
	switch -- $Window(type) {
	    "TK" {
		if { $geo ne "" } {
		    wm geometry $Window(widget) $geo
		    __trigger $whnd GeometrySet $geo
		}
		set geo [wm geometry $Window(widget)]
		__trigger $whnd GeometryGet $geo
		return $geo
	    }
	    "WINDOWS" {
		if { $geo ne "" } {
		    if { [regexp {(=?\d+x\d+)?([\+-]?\d+[\+-]?\d+)?} $geo \
			      match size pos] } {
			set flags [list SWP_NOZORDER SWP_NOACTIVATE]
			if { $size ne "" } {
			    regexp {=?(\d+)x(\d+)} $size match w h
			} else {
			    array set winfo \
				[::winapi::GetWindowInfo $Window(whnd)]
			    set w [expr $winfo(rcWindowRight) \
				       -$winfo(rcWindowLeft)]
			    set h [expr $winfo(rcWindowBottom) \
				       -$winfo(rcWindowTop)]
			    lappend flags SWP_NOSIZE
			}
			if { $pos ne "" } {
			    regexp {([\+-]?\d+)([\+-]?\d+)} $pos match x y
			} else {
			    set x 0
			    set y 0
			    lappend flags SWP_NOMOVE
			}
			
			if { $x < 0 } {
			    set sw [::winapi::GetSystemMetrics SM_CXSCREEN]
			    set x [expr $sw + $x - $w]
			}
			if { $y < 0 } {
			    set sh [::winapi::GetSystemMetrics SM_CYSCREEN]
			    set y [expr $sh + $y - $h]
			}
			::winapi::SetWindowPos $Window(whnd) 0 \
			    $x $y $w $h $flags
			__trigger $whnd GeometrySet $geo
		    } else {
			${log}::warn \
			    "$geo is not a valid geometry specification"
		    }
		}
		array set winfo [::winapi::GetWindowInfo $Window(whnd)]
		set w [expr $winfo(rcWindowRight)-$winfo(rcWindowLeft)]
		set h [expr $winfo(rcWindowBottom) -$winfo(rcWindowTop)]
		set x $winfo(rcWindowLeft)
		set y $winfo(rcWindowTop)

		set geo "=${w}x${h}+${x}+${y}"
		__trigger $whnd GeometryGet $geo
		return $geo
	    }
	}
    }
    return ""
}


# ::winop::__real_client_area -- Tweak client area dimensions
#
#	Sometimes, the client area associated to windows does not seem
#	to include the menu associated to the window.  This procedure
#	detects these cases and recomputes the top of the client area
#	to adapt to the expected values.
#
# Arguments:
#	winfo_p	"Pointer" to an array as returned by ::winapi::GetWindowInfo
#
# Results:
#	1 if tweaked, 0 otherwise.
#
# Side Effects:
#	None.
proc ::winop::__real_client_area { whnd winfo_p } {
    variable WOP
    variable log

    set tweaked 0
    set id [__init $whnd]
    if { $id ne "" && [exists $whnd] } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window

	upvar $winfo_p winfo

	set title_height [::winapi::GetSystemMetrics SM_CYCAPTION]
	set menu_height [::winapi::GetSystemMetrics SM_CYMENU]
	
	if { [expr $winfo(rcWindowTop) + $title_height + $menu_height \
		  + $winfo(cxWindowBorders)] == $winfo(rcClientTop) } {
	    set winfo(rcClientTop) [expr $winfo(rcWindowTop) + $title_height]
	    set tweaked 1
	}

	# Apply hints, if there are any
	if { [llength $Window(hints)] > 0 } {
	    foreach dir {left top right bottom} {
		set hints(-offset${dir}) 0
	    }
	    array set hints $Window(hints)
	    foreach {dir sign} {left 1 top 1 right -1 bottom -1} {
		set idx [string replace $dir 0 0 \
			     [string toupper [string index $dir 0]]]
		if { $hints(-offset${dir}) != 0 } {
		    incr winfo(rcClient${idx}) \
			[expr $sign * $hints(-offset${dir})]
		    set tweaked 1
		}
	    }
	}
    }

    return $tweaked
}


# ::winop::innergeometry -- Compute inner geometry of window
#
#	This procedure computes the inner geomtery of a window, or the
#	geometry of the client area as windows calls it.  This
#	procedure takes however into account the tweaks that have been
#	imposed by external callers.
#
# Arguments:
#	whnd	Raw handle (as an integer or in hex) or Tk window name
#
# Results:
#	Returns the geometry
#
# Side Effects:
#	None.
proc ::winop::innergeometry { whnd } {
    variable WOP
    variable log

    set id [__init $whnd]
    if { $id ne "" && [exists $whnd] } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window
	
	array set winfo [::winapi::GetWindowInfo $Window(whnd)]
	__real_client_area $Window(whnd) winfo

	set w [expr $winfo(rcClientRight) - $winfo(rcClientLeft)]
	set h [expr $winfo(rcClientBottom) - $winfo(rcClientTop)]

	set geo "=${w}x${h}+$winfo(rcClientLeft)+$winfo(rcClientTop)"
	__trigger $whnd InnerGeometryGet $geo
	return $geo
    }

    return ""
}


# ::winop::__windows -- Get windows from a point
#
#	LongDescr.
#
# Arguments:
#	arg1	descr1
#	arg2	descr2
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winop::__windows { whnd x y { sx_p "" } { sy_p "" } } {
    if { $sx_p ne "" } { upvar $sx_p sx }
    if { $sy_p ne "" } { upvar $sy_p sy }
    array set winfo [::winapi::GetWindowInfo $whnd]
    __real_client_area $whnd winfo
    set sx [expr $winfo(rcClientLeft) + $x]
    set sy [expr $winfo(rcClientTop) + $y]
    set wins [::winapi::FindWindowsFromPoint $whnd $sx $sy]
    if { $x <= $winfo(rcClientRight) - $winfo(rcClientLeft) && $x >= 0 \
	     && $y <= $winfo(rcClientBottom) - $winfo(rcClientTop) \
	     && $y >= 0 } {
	set wins [linsert $wins 0 $whnd]
    }

    # Now reverse list of windows.
    set rwins [list]
    foreach w $wins { set rwins [linsert $rwins 0 $w] }

    return $rwins
}


# ::winop::__find_window -- Find windows at position
#
#	This procedure returns the list of children windows that
#	enclose a given position within a window coordinates.
#
# Arguments:
#	w	Top window to start search at
#	x	X coordinate of position in w coordinate system
#	y	Y coordinate of position in w coordinate system
#
# Results:
#	The list of windows that enclose the position, in the order of
#	the hierarchy (i.e. the window passed as a parameter first).
#
# Side Effects:
#	None.
proc ::winop::__find_windows_at_pos { w x y } {
    set width [winfo width $w]
    set height [winfo height $w]
    set wins [list]
    if { $x >= 0 && $x <= $width && $y >= 0 && $y <= $height } {
	set wins $w
    }
    foreach sub [winfo children $w] {
	set sx [winfo x $sub]
	set sy [winfo y $sub]
	set swins [__find_windows_at_pos $sub [expr $x - $sx] [expr $y - $sy]]
	set wins [concat $wins $swins]
    }
    return $wins
}


# Unused, a test to simulate the messages sent to menus to open their
# sub-menus.
proc ::winop::__open_menu { w menu idx sx sy } {
    variable WOP
    variable log
    
    set cmd [::winapi::core::flag SC_MOUSEMENU \
		 [list \
		      SC_SIZE          [expr 0xf000] \
		      SC_MOVE          [expr 0xf010] \
		      SC_MINIMIZE      [expr 0xf020] \
		      SC_ICON          [expr 0xf020] \
		      SC_MAXIMIZE      [expr 0xf030] \
		      SC_ZOOM          [expr 0xf030] \
		      SC_NEXTWINDOW    [expr 0xf040] \
		      SC_PREVWINDOW    [expr 0xf050] \
		      SC_CLOSE         [expr 0xf060] \
		      SC_VSCROLL       [expr 0xf070] \
		      SC_HSCROLL       [expr 0xf080] \
		      SC_MOUSEMENU     [expr 0xf090] \
		      SC_KEYMENU       [expr 0xf100] \
		      SC_ARRANGE       [expr 0xf110] \
		      SC_RESTORE       [expr 0xf120] \
		      SC_TASKLIST      [expr 0xf130] \
		      SC_SCREENSAVE    [expr 0xf140] \
		      SC_HOTKEY        [expr 0xf150] \
		      SC_DEFAULT       [expr 0xf160] \
		      SC_MONITORPOWER  [expr 0xf170] \
		      SC_CONTEXTHELP   [expr 0xf180] \
		      SC_SEPARATOR     [expr 0xf00f]]]
    set lprm [::winapi::core::makelparam $sx $sy]
    ::winapi::SendMessage $w WM_SYSCOMMAND $cmd $lprm
    
    ::winapi::SendMessage $w WM_ENTERMENULOOP 0 0

    ::winapi::SendMessage $w WM_INITMENU $menu 0

    set flags [::winapi::core::flags [list MF_MOUSESELECT MF_HILITE MF_POPUP] \
		   [list \
			*ENABLED          [expr 0x0] \
			*GRAYED           [expr 0x1] \
			*DISABLED         [expr 0x2] \
			*BITMAP           [expr 0x4] \
			*CHECKED          [expr 0x8] \
			*MENUBARBREAK     [expr 0x20] \
			*MENUBREAK        [expr 0x40] \
			*OWNERDRAW        [expr 0x100] \
			*POPUP            [expr 0x10] \
			*SEPARATOR        [expr 0x800] \
			*STRING           [expr 0x0] \
			*UNCHECKED        [expr 0x0] \
			*DEFAULT          [expr 0x1000] \
			*SYSMENU          [expr 0x2000] \
			*HELP             [expr 0x4000] \
			*END              [expr 0x80] \
			*RIGHTJUSTIFY     [expr 0x4000] \
			*MOUSESELECT      [expr 0x8000] \
			*INSERT           [expr 0x0] \
			*CHANGE           [expr 0x80] \
			*APPEND           [expr 0x100] \
			*DELETE           [expr 0x200] \
			*REMOVE           [expr 0x1000] \
			*USECHECKBITMAPS  [expr 0x200] \
			*UNHILITE         [expr 0x0] \
			*HILITE           [expr 0x80]]]
    set wprm [::winapi::core::makewparam $idx $flags]
    ::winapi::SendMessage $w WM_MENUSELECT $wprm $menu

    set lprm [::winapi::core::makelparam $idx 0]
    ::winapi::SendMessage $w WM_INITMENUPOPUP $menu $lprm
}


# ::winop::__menubar_select -- Detect selection in menubars
#
#	This procedure returns menu information if a given location is
#	on top of one of the items of the menu bar of a window.
#
# Arguments:
#	w	Window handle
#	sx	X position in screen coordinates
#	sy	Y position in screen coordinates
#
# Results:
#	A list composed of, respectively, the handle of the menu for
#	that menubar and the index of the item within that menu.  An
#	empty list is returned on errors and when the position is not
#	on top of a known menu bar.
#
# Side Effects:
#	None.
proc ::winop::__menubar_select { w sx sy } {
    variable WOP
    variable log

    # Get the standard menubar (as opposed to the right-click menu and
    # the system (close, etc.) menu and check that the menubar
    # actually has a menu associated to it.
    set info [::winapi::GetMenuBarInfo $w OBJID_MENU 0]
    if { $info eq "" } {
	return [list]
    }
    array set barinfo $info
    if { $barinfo(hMenu) == 0 } {
	return [list]
    }

    # See to have MODELESS menus in the menu bar.  By making these
    # menus modeless, we ensure that clicking somewhere else (our
    # canvas for example) will not remove the menu from the screen.
    # This will allow us to click on their virtual representation and
    # forward this click accordingly.
    ::winapi::AddMenuStyle $barinfo(hMenu) MNS_MODELESS

    # Now parse through all items of the menu bar to detect their
    # enclosing rectangle (in screen coordinates) and detect within
    # which (if any) rectangle the position is.
    set i 1
    while {$i<32768} {
	set info [::winapi::GetMenuBarInfo $w OBJID_MENU $i]
	if { $info eq "" } {
	    break
	}
	array set bitminfo $info
	if { $sx >= $bitminfo(rcBarLeft) \
		 && $sy >= $bitminfo(rcBarTop) \
		 && $sx <= $bitminfo(rcBarRight) \
		 && $sy <= $bitminfo(rcBarBottom) } {
	    array set itminfo \
		[::winapi::GetMenuItemInfo $barinfo(hMenu) [expr $i - 1] on]
	    return [list $barinfo(hMenu) \
			[expr $i - 1] \
			"$itminfo(dwTypeData)" \
		       $itminfo(wID)]
	}
	incr i
    }
    return [list]
}


# unused
proc ::winop::__menu_select { w sx sy } {
    variable WOP
    variable log

    set menu [::winapi::GetMenu $w]
    if { $menu eq "" || $menu == "0" } {
	${log}::warn "Cannot find menu for $w!"
	#return 0
    } else {
	${log}::debug "Menu handle is $menu"
    }

    set tid [lindex [::winapi::GetWindowThreadProcessId $w] 1]
    array set tinfo [::winapi::GetGUIThreadInfo $tid]
    set owner $tinfo(hwndMenuOwner)
    puts "MENU of owner: [::winapi::GetMenu $owner]"
    set menu [::winapi::GetMenu $owner]
    puts "Screen coords: $sx $sy"
    array set minfo [::winapi::GetMenuInfo $menu]
    parray minfo
    puts "--"
    set nb_items [::winapi::GetMenuItemCount $menu]
    for {set i 0} {$i < $nb_items} {incr i} {
	array set itminfo [::winapi::GetMenuItemInfo $menu $i on]
	parray itminfo
    }
    return 0
    set itm [::winapi::MenuItemFromPoint $menu $sx $sy $w]
    puts "ITEM is perhaps: $itm"
    if { $owner ne "" && $itm >= 0 } {
	set flags [::winapi::core::flags [list MF_MOUSESELECT MF_HILITE] \
		       [list \
			    *ENABLED          [expr 0x0] \
			    *GRAYED           [expr 0x1] \
			    *DISABLED         [expr 0x2] \
			    *BITMAP           [expr 0x4] \
			    *CHECKED          [expr 0x8] \
			    *MENUBARBREAK     [expr 0x20] \
			    *MENUBREAK        [expr 0x40] \
			    *OWNERDRAW        [expr 0x100] \
			    *POPUP            [expr 0x10] \
			    *SEPARATOR        [expr 0x800] \
			    *STRING           [expr 0x0] \
			    *UNCHECKED        [expr 0x0] \
			    *DEFAULT          [expr 0x1000] \
			    *SYSMENU          [expr 0x2000] \
			    *HELP             [expr 0x4000] \
			    *END              [expr 0x80] \
			    *RIGHTJUSTIFY     [expr 0x4000] \
			    *MOUSESELECT      [expr 0x8000] \
			    *INSERT           [expr 0x0] \
			    *CHANGE           [expr 0x80] \
			    *APPEND           [expr 0x100] \
			    *DELETE           [expr 0x200] \
			    *REMOVE           [expr 0x1000] \
			    *USECHECKBITMAPS  [expr 0x200] \
			    *UNHILITE         [expr 0x0] \
			    *HILITE           [expr 0x80]]]
	set wprm [::winapi::core::makewparam $itm $flags]
	::winapi::SendMessage $owner WM_MENUSELECT $wprm $menu

	# XXX: Really we should issue a WM_COMMAND with the ID (as in
	# GetMenuItemID?) of the item that was selected.

	# XXX: When clicking on menubar (eg. notepad) we should probably
	# post the submenu ourselves
	return 1
    } else {
	${log}::warn \
	    "No menu item at <${x},${y}> (<${sx},${sy}>)\
                                 or no owner: '$owner'"
	return 0
    }

    return 0; #Never reached
}


proc ::winop::__raise_simulate { whnd btn x y } {
    variable WOP
    variable log

    # Remember the current state: position of the mouse pointer, etc.
    foreach {ox oy} [::winapi::GetCursorPos] break
    set top [::winapi::GetActiveWindow]

    if {0} {
    set tid [lindex [::winapi::GetWindowThreadProcessId $whnd] 1]
    set ourtid [::winapi::GetCurrentThreadId]
    ::winapi::AttachThreadInput $tid $ourtid on
    set old_active [::winapi::SetActiveWindow $whnd]
    }

    # Raise the window to the top
    ::winapi::SetWindowPos $whnd SWP_TOP 0 0 0 0 [list SWP_NOMOVE SWP_NOSIZE]

    # Now match the tcl-way of expressing buttons to the way the
    # SendMouseInput likes and simulates the mouse click.
    array set buttons [list 1 LEFT 2 MIDDLE 3 RIGHT]
    ${log}::debug \
	"Simulating $buttons($btn) button click at <${x},${y}>\
         on raised window $whnd"
    
    # Do not forget that SendMouseInput wishes to have very precise
    # coordinates where the maximum is 65535
    set sx [::winapi::GetSystemMetrics SM_CXSCREEN]
    set sy [::winapi::GetSystemMetrics SM_CYSCREEN]
    set dx [expr {$x * 65535 / $sx}]
    set dy [expr {$y * 65535 / $sy}]
    set flags [list \
		   "MOUSEEVENTF_MOVE" \
		   "MOUSEEVENTF_$buttons($btn)DOWN" \
		   "MOUSEEVENTF_$buttons($btn)UP" \
		   "MOUSEEVENTF_ABSOLUTE"]
    ::winapi::SendMouseInput $dx $dy $flags
    
    # Send back the pointer to its original position
    set dx [expr {$ox * 65535 / $sx}]
    set dy [expr {$oy * 65535 / $sy}]
    set flags [list \
		   "MOUSEEVENTF_MOVE" \
		   "MOUSEEVENTF_ABSOLUTE"]
    ::winapi::SendMouseInput $dx $dy $flags
    #::winapi::SetWindowPos $top SWP_TOP 0 0 0 0 [list SWP_NOMOVE SWP_NOSIZE]
}


# ::winop::button -- Simulate button press/release
#
#	This procedure simulate the pressing/release of mouse buttons
#	under the child windows of window at a given point.
#
# Arguments:
#	whnd	Raw handle (as an integer or in hex) or Tk window name
#	action	ButtonPress or ButtonRelease
#	btn	Number of button being pressed.
#	x	X (relative to window) coordinate
#	y	Y (relative to window) coordinate
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winop::button { whnd action btn x y } {
    variable WOP
    variable log

    set id [__init $whnd]
    if { $id ne "" && [exists $whnd] } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window

	switch -- $Window(type) {
	    "TK" {
		
		# To simulate the event, we need to simulate: enter in
		# the window, press the mouse button, then release
		# (and leave for completeness).  We should find the
		# window that is a leaf of the tree and encloses the
		# <x,y> coordinates to perform this on (and give the x
		# and y in window coordinates).

		# XXX: This is not tested, but should work according
		# to the documentation.
		switch -glob -- $action {
		    *Press { set evt "<ButtonPress>" }
		    *Release { set evt "<ButtonRelease>" }
		    default { set evt "" }
		}
		if { $evt ne "" } {
		    set rx [expr [winfo rootx $Window(widget)] + $x]
		    set ry [expr [winfo rooty $Window(widget)] + $y]
		    set wins [__find_windows_at_pos $Window(widget) $x $y]
		    if { [string is false $WOP(-clickwholetree)] } {
			set wins [lindex $wins end]
		    }
		    ${log}::debug "Simulating $evt to windows: $wins"
		    foreach w $wins {
			set wx [expr $rx - [winfo rootx $w]]
			set wy [expr $ry - [winfo rooty $w]]
			if { $evt eq "<ButtonPress>" } {
			    # Trigger *before* to leave any chance to
			    # do something.
			    __trigger $whnd Enter $w
			    event generate $w <Enter>
			}
			set tevt [string map [list ">" "-${btn}>"] $evt]
			event generate $w $evt -button $btn -x $wx -y $wy
			__trigger $whnd Button $w $tevt $wx $wy
			if { $evt eq "<ButtonRelease>" } {
			    event generate $w <Leave>
			    __trigger $whnd Leave $w
			}
		    }
		}
	    }
	    "WINDOWS" {
		# Translate Tk-like actions and buttons to Windows-style
		switch -glob -- $action {
		    *Press {
			set act "DOWN"
			set tevt "<ButtonPress-${btn}>"
		    }
		    *Release {
			set act "UP"
			set tevt "<ButtonPress-${btn}>"
		    }
		}
		array set buttons [list 1 L 2 M 3 R]
		set msg "WM_$buttons($btn)BUTTON$act"
		set whnd $Window(whnd)

		# Reset click window history
		set oldhistory $Window(history_${msg})
		set Window(history_${msg}) [list]
		set now [clock clicks -milliseconds]

		# Attach to remote window.
		if {0 } {
		    set tid \
			[lindex [::winapi::GetWindowThreadProcessId $whnd] 1]
		    set ourtid [::winapi::GetCurrentThreadId]
		    ::winapi::AttachThreadInput $tid $ourtid on
		    set old_active [::winapi::SetActiveWindow $whnd]
		}

		# Convert the relative click location to screen
		# coordinates, find all windows that are sub-windows
		# of the window at that screen point and simulate
		# click within these in the hierarchy, in reverse
		# order.
		set rwins [__windows $whnd $x $y sx sy]
		if { [llength $rwins] == 0 } {
		    ${log}::warn \
			"Could not find sub of 0x[format %x $whnd] at\
                         ($sx,$sy)"
		} else {
		    # Simulate mouse selection in menus.
		    set mb [__menubar_select $whnd $sx $sy]
		    if { [llength $mb] > 0 && $act eq "UP" } {
			foreach {hmenu idx str mid} $mb break
			__raise_simulate $whnd $btn $sx $sy
			return
		    }
		    set cls [::winapi::GetClassName $whnd]
		    if { $cls eq "\#32768" } {
		    }

		    # send the input starting from the one at the
		    # bottom of the tree.
		    set receivers 0
		    foreach w $rwins {
			::winapi::SimulateMouseInput $w $sx $sy 1 $msg
			__trigger $whnd Button $w $tevt $sx $sy
			incr receivers
			if { $receivers >= $WOP(maxreceivers) } {
			    break
			}
		    }

		    # Now analyse and send double click if appropriate
		    if { $act == "UP" && [llength $oldhistory] > 0 } {
			array set history $oldhistory
			set dclick [::winapi::GetDoubleClickTime]
			if { $now - $history(time) < $dclick } {
			    if { [expr abs($x-$history(x))] \
				     < $WOP(-dclick_precision) \
				     && [expr abs($y-$history(y))] \
				     < $WOP(-dclick_precision) } {
				${log}::info \
				    "Simulating double click at ($sx,$sy)"
				set receivers 0
				foreach w $rwins {
				    ::winapi::SimulateMouseInput $w $sx $sy 1 \
					[regsub $act $msg "DBLCLK"]
				    __trigger $whnd Button $w \
					"<Double-${btn}>" $sx $sy
				    incr receivers
				    if { $receivers >= $WOP(maxreceivers) } {
					break
				    }
				}
			    }
			}
		    }

		    # Store button press tree history in window
		    # context so that we will be able to fetch it back
		    # for key press simulation.
		    set history(windows) $rwins
		    set history(time) $now
		    set history(x) $x
		    set history(y) $y
		    switch -glob -- $action {
			*Press {
			    set Window(history_${msg}) [array get history]
			}
			*Release {
			    set Window(history_${msg}) [array get history]
			}
		    }
		}

		if { 0 } {
		    ::winapi::AttachThreadInput $tid $ourtid off
		    set tid \
			[lindex [::winapi::GetWindowThreadProcessId $old_active] 1]
		    ::winapi::AttachThreadInput $tid $ourtid on
		    ::winapi::SetActiveWindow $old_active
		    ::winapi::AttachThreadInput $tid $ourtid off
		}
	    }
	}
    }
}


# ::winop::motion -- Simulate mouse motion events.
#
#	This procedure simulate mouse motion events under the child
#	windows of a window at a given point.
#
# Arguments:
#	whnd	Raw handle (as an integer or in hex) or Tk window name
#	btn	Number of button being pressed (possibly empty)
#	x	X (relative to window) coordinate
#	y	Y (relative to window) coordinate
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winop::motion { whnd btn x y } {
    variable WOP
    variable log

    set id [__init $whnd]
    if { $id ne "" && [exists $whnd] } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window

	switch -- $Window(type) {
	    "TK" {
		# XXX: This is not tested, but should work according
		# to the documentation.
		event generate $Window(widget) <Motion> -x $x -y $y
		__trigger $whnd Motion $whnd $x $y
	    }
	    "WINDOWS" {
		# Convert the relative click location to screen
		# coordinates, find all windows that are sub-windows
		# of the window at that screen point and simulate
		# click within these in the hierarchy, in reverse
		# order.
		set rwins [__windows $Window(whnd) $x $y sx sy]
		if { [llength $rwins] == 0 } {
		    ${log}::warn \
			"Could not find sub of 0x[format %x $Window(whnd)] at\
                         ($sx,$sy)"
		} else {
		    # send the input starting from the one at the
		    # bottom of the tree.
		    set receivers 0
		    set btn [string map {L 1 R 2 M 16} $btn]
		    if { $btn eq "" } { set btn 0 }
		    foreach w $rwins {
			::winapi::SimulateMouse $w $sx $sy WM_MOUSEMOVE $btn
			__trigger $whnd Motion $w $sx $sy
			incr receivers
			if { $receivers >= $WOP(maxreceivers) } {
			    break
			}
		    }
		}
	    }
	}
    }
}


# ::winop::key -- Simulate key press/release
#
#	This procedure simulate the pressing/release of keys under the
#	child windows of window at a given point.  The current
#	implementation needs that ::winop::button has been called at
#	least once before this procedure to function properly.
#
# Arguments:
#	whnd	Raw handle (as an integer or in hex) or Tk window name
#	action	KeyPress or KeyRelease
#	keysym	keysym (as in X11) of key
#	keycode	keycode of key
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winop::key { whnd action keysym keycode } {
    variable WOP
    variable log
    variable KeySymDB

    set id [__init $whnd]
    if { $id ne "" && [exists $whnd] } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window

	switch -- $Window(type) {
	    "TK" {
		# XXX: This is not tested, but should work according
		# to the documentation.
		set evt "<${action}>"
		set f [focus]
		focus $Window(widget)
		set opts ""
		if { $keysym ne "" } { lappend opts -keysym $keysym }
		if { $keycode ne "" } { lappend opts -keycode $keycode }
		eval event generate $Window(widget) $evt $opts
		focus $f
	    }
	    "WINDOWS" {
		# One solution that I was looking into was the
		# following, but it never worked since that would
		# bring the window to the foreground.  That solution
		# would have had the advantage of letting keybd_event
		# do all the bad translating job.

		# set cur [::winapi::GetCurrentThreadId]
		# set other [lindex [::winapi::GetWindowThreadProcessId $whnd] 1]
		# ::winapi::AttachThreadInput $other $cur 1
		# ::winapi::SetFocus $whnd
		# ::winapi::SendMultiKeys "toto"
		# ::winapi::AttachThreadInput $other $cur 0

		# Translate Tk-like actions and buttons to Windows-style
		switch -glob -- $action {
		    *Press { set act "WM_KEYDOWN" }
		    *Release { set act "WM_KEYUP" }
		}
		
		${log}::debug "Treating $act: sym: '$keysym' code: '$keycode'"
		
		set whnd $Window(whnd)
		if { [llength $Window(history_WM_LBUTTONDOWN)] == 0 } {
		    ${log}::warn "No previous mouse event on\
                                  0x[format %x $whnd] to build upon"
		} else {
		    if { $keycode eq "" } {
			if { $keysym ne "" } {
			    if { [array names KeySymDB $keysym] ne "" } {
				set uchar $KeySymDB($keysym)
				set keycode [::winapi::VkKeyScan $uchar]
			    }
			}
		    }

		    if { $keycode eq "" } {
			${log}::warn "Cannot send $act for $keysym, no code"
			return
		    }
		    array set history $Window(history_WM_LBUTTONDOWN)
		    set receivers [lindex $history(windows) 0]
		    foreach w $receivers {
			set res [::winapi::SendMessage $w $act $keycode 0]
			if { $res } { break }
		    }
		    if { $act == "WM_KEYDOWN" } {
			# Send the translated keysym to the window as
			# a WM_CHAR. Maybe could we use the keycode
			# instead here, dunno really.
			if { [array names KeySymDB $keysym] ne "" } {
			    foreach w $receivers {
				set res [::winapi::SendMessage $w WM_CHAR \
					     $KeySymDB($keysym) 0]
				if { $res } { break }
			    }
			} else {
			    ${log}::debug "Cannot find keysym <$keysym> in DB"
			}
		    }
		}
	    }
	}
    }
}


# ::winop::hints -- Associate hints to windows
#
#	This procedure allows external callers to associate hints to
#	windows, these hints will help this module when simulating
#	input events.
#
# Arguments:
#	whnd	Window handle
#	hints	Hints, as a list of dash led options and values.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winop::hints { whnd hints } {
    variable WOP
    variable log

    set id [__init $whnd]
    if { $id ne "" && [exists $whnd] } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window
	
	set Window(hints) $hints
    }
}


# ::winop::monitor -- Event monitoring system
#
#	This command will arrange for a callback every time an
#	operation which name matches the pattern passed as a parameter
#	occurs within a window.  The callback will be called with the
#	identifier of the window, followed by the name of the
#	operation and followed by a number of additional arguments
#	which are event dependent.
#
# Arguments:
#	whnd	Window handle
#	ptn	String match pattern for event name
#	cb	Command to callback every time a matching operation occurs.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winop::monitor { whnd ptn cb } {
    variable WOP
    variable log

    set id [__init $whnd]
    if { $id ne "" && [exists $whnd] } {
	set varname "::winop::Window_$id"
	upvar \#0 $varname Window

	lappend Window(callbacks) $ptn $cb
    }
}


# ::winop::defaults -- Set/Get settings for module
#
#	This command sets or gets the settings for this module.
#
# Arguments:
#	args	List of -key value or just -key to get value
#
# Results:
#	Return all options, the option requested or set the options
#
# Side Effects:
#	None.
proc ::winop::defaults { args } {
    variable WOP
    variable log

    set o [lsort [array names WOP "-*"]]

    if { [llength $args] == 0 } {      ;# Return all results
	set result ""
	foreach name $o {
	    lappend result $name $WOP($name)
	}
	return $result
    }

    foreach {opt value} $args {        ;# Get one or set some
	if { [lsearch $o $opt] == -1 } {
	    return -code error "Unknown option $opt, must be: [join $o ,]"
	}
	if { [llength $args] == 1 } {  ;# Get one config value
	    return $WOP($opt)
	}
	set WOP($opt) $value           ;# Set the config value
    }
}


package provide winop 0.4
