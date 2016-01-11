# winapix.tcl --
#
#	This modules provides a number of additional functionality
#	(usually at a higher degree of abstraction) on top of the
#	winapi.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# We need Ffidl since we will be creating loads of callouts
package require winapi

# Create the namespace, further initialisation will be done at the end
# of this file.
namespace eval ::winapi {
    variable WINAPIX
    if { ! [info exists WINAPIX] } {
	array set WINAPIX {
	    idgene     0
	}
    }
}


# ::winapi::FindWindows -- Find sub windows by pattern.
#
#	This procedure finds all direct sub windows of a window that
#	matches a given pattern.
#
# Arguments:
#	parent	Parent top window under which to look for window.
#	class	Class pattern (string match-like) of window.
#	title	Title pattern (string match-like) of window.
#
# Results:
#	Returns the handles of the windows that match the input patterns.
#
# Side Effects:
#	None.
proc ::winapi::FindWindows { parent class title } {
    set wins ""
    set w [FindWindowEx $parent 0 "" ""]
    for { } { $w != 0 } { set w [FindWindowEx $parent $w "" ""] } {
	if { [string match $class [GetClassName $w]] \
		 && [string match $title [GetWindowText $w]] } {
	    lappend wins $w
	}
    }
    
    return $wins
}


# ::winapi::FindWindowsFromPoint -- ShortDescr.
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
proc ::winapi::FindWindowsFromPoint { parent x y } {
    set wins ""
    foreach w [WindowTree $parent] {
	foreach {x1 y1 x2 y2} [GetWindowRect $w] break
	if { $x >= $x1 && $x < $x2 && $y >= $y1 && $y < $y2 } {
	    lappend wins $w
	}
    }
    
    return $wins
}


# ::winapi::WindowTree -- Return whole window tree
#
#	This procedure finds all the windows that are a descendant of
#	a given window.
#
# Arguments:
#	w	Parent top window for which to return the tree.
#
# Results:
#	Returns the handles of all descendant of the window which
#	handle is passed as a parameter.
#
# Side Effects:
#	None.
proc ::winapi::WindowTree { w } {
    set subs [FindWindows $w * *]
    set res $subs
    foreach s $subs {
	set res [concat $res [WindowTree $s]]
    }

    return $res
}


# ::winapi::FindDescendantWindows -- Find descendant windows by pattern.
#
#	This procedure finds all descendant windows (whole tree!) of a
#	window that matches a given pattern.
#
# Arguments:
#	parent	Parent top window under which to look for window.
#	class	Class pattern (string match-like) of window.
#	text	Text pattern (string match-like) of window.
#
# Results:
#	Returns the handles of the windows that match the input patterns.
#
# Side Effects:
#	None.
proc ::winapi::FindDescendantWindows { parent class text } {
    set wins ""
    foreach w [WindowTree $parent] {
	if { [string match $class [GetClassName $w]] \
		 && [string match $text [GetWindowText $w]] } {
	    lappend wins $w
	}
    }
    
    return $wins
}


# ::winapi::__ww_check -- Check for a windows in hiearchy
#
#	Check for windows that match the context passed as a parameter
#	in the window hierarchy and perform the necessary callbacks.
#
# Arguments:
#	id	Identifier of wait, as returned by WaitWindows.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winapi::__ww_check { id } {
    variable log

    # Get to context
    set varname "::winapi::__ww_${id}"
    if { [info exists $varname] } {
	upvar \#0 $varname WC

	# Look for the descendants of the top window in the context
	set wins [FindDescendantWindows $WC(top) $WC(class) $WC(text)]
	${log}::debug "Descendants of $WC(top) (matching C:'$WC(class)' and\
                       T:'$WC(text)') are: $wins"
	if { $wins != "" } {
	    # We have some windows, do the callback if necessary or
	    # mediate to the caller (via the context) that we have
	    # found the windows.
	    set WC(wins) $wins
	    if { $WC(cb) != "" } {
		if { [catch {eval $WC(cb) $WC(top) \{$WC(wins)\}} err] } {
		    ${log}::warn "Failed executing window wait callback: $err"
		}
		unset WC
	    }
	} else {
	    # We don't have any windows matching, test again.
	    set WC(aid) [after $WC(period) ::winapi::__ww_check $id]
	}
    }
}


# ::winapi::CancelWaitWindows -- Cancel a Wait for windows
#
#	Cancel an asynchronous wait for windows in a hierarchy.
#
# Arguments:
#	id	Identifier of wait, as returned by WaitWindows.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winapi::CancelWaitWindows { id } {
    variable log

    set varname "::winapi::__ww_${id}"
    if { [info exists $varname] } {
	upvar \#0 $varname WC
	after cancel $WC(aid)
	if { $WC(cb) == "" } {
	    # Unblock the caller if no callback (internal unblocking).
	    set WC(wins) "CANCELLED"
	} else {
	    unset WC
	}
    }
}


# ::winapi::WaitWindows -- Wait for windows
#
#	Synchronously or asynchronously Wait one or more windows
#	matching a given text and class to be present under a given
#	window.
#
# Arguments:
#	top	Handle of the top window (0 means desktop)
#	cls	Pattern matching for the class of the windows to wait for
#	txt	Pattern matching for the text of the windows to wait for
#	cb	The callback that will be called,handles of top window
#               and list of matching windows will be appended. Empty to block.
#       howlong How long to wait for the window, negative means forever
#       period  Period for checking
#
# Results:
#	Return either the handle of the window or a handle to an
#	identifier that can be used to stop waiting for the window.
#
# Side Effects:
#	None.
proc ::winapi::WaitWindows { top cls txt {cb ""} {howlong -1} {period 250}} {
    variable WINAPIX
    variable log

    # Create a context
    set id [incr WINAPIX(idgene)]
    set varname "::winapi::__ww_${id}"
    upvar \#0 $varname WC
    
    # Store all arguments in the context
    set WC(id) $id
    set WC(cb) $cb
    set WC(period) $period
    set WC(class) $cls
    set WC(text) $txt
    set WC(top) $top
    set WC(wins) ""
    # Arrange to cancel the check in a given period of time, if necessary.
    if { $howlong >= 0 } {
	after $howlong ::winapi::CancelWaitWindows $id
    }
    # And start polling
    set WC(aid) [after idle ::winapi::__ww_check $id]
    if { $cb == "" } {
	# If we are blocking, wait for the variable to contain
	# something. You'd better have something for howlong,
	# otherwise you could block forever!
	vwait ::winapi::__ww_${id}(wins)
	if { $WC(wins) == "CANCELLED" } {
	    set wins ""
	} else {
	    set wins $WC(wins)
	}
	unset WC
	return $wins
    } else {
	return $id
    }
}


# ::winapi::GetWindowsRect -- Get windows rect
#
#	This procedure extracts the rectangle enclosing one or several
#	window(s).
#
# Arguments:
#	wins	List of window handles to get information from
#
# Results:
#	Returns a repetitive list of handle, left, top, right and
#	bottom for each window handles passed as a parameter.
#
# Side Effects:
#	None.
proc ::winapi::GetWindowsRect { wins } {
    variable log

    set allwins [list]
    foreach w $wins {
	set rect [::winapi::GetWindowRect $w]
	foreach {left top right bottom} $rect {}
	lappend allwins $w $left $top $right $bottom
    }
    return $allwins
}


proc ::winapi::__isModifier { seq } {
    set modifiers [list "*CONTROL" "*SHIFT" "*MENU"]
    foreach mod $modifiers {
	if { [string match -nocase $mod $seq] } {
	    return 1
	}
    }
    return 0
}

proc ::winapi::SendMultiKeys { sequence } {
    set keylist [list]
    set i 0
    while { $i < [string length $sequence] } {
	set char [string index $sequence $i]
	if { $char == "<" } {
	    set close [string first ">" $sequence $i]
	    if { $close == [expr $i + 1] \
		     && [string index $sequence [expr $close + 1]] == ">" } {
		incr close
	    }
	    lappend keylist [string range $sequence \
				 [expr $i + 1] [expr $close -1]]
	    set i [expr $close + 1]
	} else {
	    lappend keylist $char
	    incr i
	}
    }

    set inmods [list]
    foreach k $keylist {
	if { [__isModifier $k] } {
	    ::winapi::SendKeyboardInput $k
	    lappend inmods $k
	} else {
	    ::winapi::SendKeyboardInput $k
	    ::winapi::SendKeyboardInput $k KEYUP
	    if { [llength $inmods] >= 0 } {
		foreach m $inmods {
		    ::winapi::SendKeyboardInput $m KEYUP
		}
		set inmods [list]
	    }
	}
    }
}


proc ::winapi::mixerGetVolumeControl { componentType ctrlType { mixID 0 } } {
    set mixer [::winapi::mixerOpen $mixID]
    array set mxl [::winapi::mixerGetLineInfo $mixer \
		       MIXER_GETLINEINFOF_COMPONENTTYPE \
		       dwComponentType $componentType]
    
    array set mxc [::winapi::mixerGetLineControls $mixer \
		       MIXER_GETLINECONTROLSF_ONEBYTYPE \
		       dwLineID $mxl(dwLineID) \
		       dwControl $ctrlType]
    set val [::winapi::mixerGetControlDetails $mixer \
		 MIXER_GETCONTROLDETAILSF_VALUE \
		 dwControlID $mxc(dwControlID) cChannels 1]
    ::winapi::mixerClose $mixer
}


# ::winapi::SimulateMouseInput -- Simulate mouse input
#
#	LongDescr.
#
# Arguments:
#	w	Window where to simulate
#	x	X coordinate
#	y	Y coordinate 
#	actions	List of actions to be performed in order (DOWN or UP)
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winapi::SimulateMouseInput { w x y {screencoords 1} {actions "LBUTTONDOWN LBUTTONUP"} } {
    variable log

    if { $screencoords } {
	foreach {x1 y1 x2 y2} [GetWindowRect $w] break
	set x [expr $x - $x1]
	set y [expr $y - $y1]
    }

    set pos [::winapi::core::makelparam $x $y]
    foreach a $actions {
	set a [string toupper $a]
	if { [string first "DOWN" $a] >= 0 } {
	    set b [string first "BUTTON" $a]
	    set which [string index $a [expr $b - 1]]
	    set arg [string map {L 1 R 2 M 16} $which]
	    if { ! [::winapi::PostMessage $w $a $arg $pos] } {
		${log}::warn "Could not post $a to window $w at <$x,$y>"
	    }
	} else {
	    if { ! [::winapi::PostMessage $w $a 0 $pos] } {
		${log}::warn "Could not post $a to window $w at <$x,$y>"
	    }
	}
    }
}

proc ::winapi::SimulateMouse { w x y msg {arg 0 } {screencoords 1} } {
    variable log

    if { $screencoords } {
	foreach {x1 y1 x2 y2} [GetWindowRect $w] break
	set x [expr $x - $x1]
	set y [expr $y - $y1]
    }

    set pos [expr ($y * 0x10000) + ($x & 0xFFFF)]
    if { ! [::winapi::PostMessage $w $msg $arg $pos] } {
	${log}::warn "Could not post $a to window $w at <$x,$y>"
    }
}


# ::winapi::AddMenuStyle -- (Recursively) add a style to a menu
#
#	This procedure gives a new style to a menu and possibly all
#	its sub-menus.
#
# Arguments:
#	menu	Handle to menu
#	style	New style to add to menu
#	recur	Should we treat sub-menus as well?
#
# Results:
#	0 on failures, non-zero on success
#
# Side Effects:
#	This procedure can have direct implications for the user, for
#	example, when used with the MNS_MODELESS style.
proc ::winapi::AddMenuStyle { menu style { recur on } } {
    variable log

    # Change the style of the menu if necessary
    set nfo [::winapi::GetMenuInfo $menu]
    if { $nfo eq "" } {
	return 0
    }
    array set minfo $nfo
    set res 1
    if { [lsearch $minfo(dwStyle) $style] < 0 } {
	lappend minfo(dwStyle) $style
	if { [::winapi::SetMenuInfo $menu [array get minfo] MIM_STYLE] } {
	    ${log}::info "Given stype $style to menu \#$menu"
	} else {
	    set res 0
	}
    }

    # And recurse through all sub menus.
    if { [string is true $recur] } {
	set nb_items [::winapi::GetMenuItemCount $menu]
	for {set i 0} {$i < $nb_items} {incr i} {
	    array set itminfo [::winapi::GetMenuItemInfo $menu $i on]
	    if { $itminfo(hSubMenu) != 0 } {
		set res \
		    [expr $res \
			 && [AddMenuStyle $itminfo(hSubMenu) $style $recur]]
	    }
	}
    }
    
    return $res
}


# ::winapi::__is_topmost -- Is a window on top?
#
#	Detect if a window is on top of all other windows (topmost).
#
# Arguments:
#	w	Handle to window
#
# Results:
#	Returns 1 if it is topmost, 0 otherwise
#
# Side Effects:
#	None.
proc ::winapi::__is_topmost { w } {
    variable log

    # Get window status
    array set winfo [::winapi::GetWindowInfo $w]
    
    # Analyse result, make sure we can even if we failed getting any
    # dwExStyle
    if { [array names winfo dwExStyle] != "" \
	     && [lsearch -glob $winfo(dwExStyle) "*TOPMOST"] >= 0 } {
	set is_topmost 1
    } else {
	set is_topmost 0
    }

    return $is_topmost
}


# ::winapi::SendKeys -- Send key sequence
#
#	This procedure sends a key sequence to a window by raising it
#	on top of all other windows for the time of the interaction.
#
# Arguments:
#	hwnd	Handle to window
#	keys	Key sequence to send
#	restore	Should the window be restored to its position afterwards?
#
# Results:
#	1 on success, 0 otherwise
#
# Side Effects:
#	None.
proc ::winapi::SendKeys { hwnd keys {restore on}} {
    variable log

    # Remember current position of mouse pointer and current stack
    # state of window
    foreach {oldx oldy} [::winapi::GetCursorPos] {}
    set was_topmost [__is_topmost $hwnd]
    if { ! $was_topmost } {
	${log}::debug "Forcing $hwnd on top of all other windows"
	# Put it on top of all other windows.
	::winapi::SetWindowPos $hwnd HWND_TOPMOST
    }

    # Send the mouse at the middle of the video window (this is in
    # case we have focus follow mouse).
    foreach {left top right bottom} [::winapi::GetWindowRect $hwnd] {}
    set x [expr $left + (($right - $left) / 2)]
    set y [expr $top + (($bottom - $top) / 2)]
    set sx [::winapi::GetSystemMetrics SM_CXSCREEN]
    set sy [::winapi::GetSystemMetrics SM_CYSCREEN]
    ::winapi::SendMouseInput [expr {$x * 65535 / $sx}] \
	[expr {$y * 65535 / $sy}] \
	{ABSOLUTE MOVE LEFTDOWN LEFTUP}

    # Send the keys and restore the state of the window and the mouse
    # pointer.
    ::winapi::SendMultiKeys $keys

    # Get the window and mouse pointer back to what they were
    if { [string is true $restore] } {
	__back_to_normal $hwnd $oldx $oldy $was_topmost
    } else {
	__back_to_normal $hwnd $oldx $oldy 0
    }

    return 1
}


# __back_to_normal -- Send window and mouse back to normal
#
#	This procedure sends back the mouse pointer to a given
#	location and forces back a window not to be top most if it was
#	not in the past.
#
# Arguments:
#	hwnd	Handle of window
#	oldx	X Position of mouse
#	oldy	Y Position of mouse
#	was_top	Was the window topmost before.
#
# Results:
#	None.
#
# Side Effects:
#	As described
proc ::winapi::__back_to_normal { hwnd oldx oldy was_top } {
    variable log

    if { ! $was_top } {
	${log}::debug "Restoring $hwnd to no topmost"
	::winapi::SetWindowPos $hwnd HWND_NOTOPMOST
    }

    # Send back the mouse pointer to its old position
    set sx [::winapi::GetSystemMetrics SM_CXSCREEN]
    set sy [::winapi::GetSystemMetrics SM_CYSCREEN]
    ::winapi::SendMouseInput [expr {$oldx * 65535 / $sx}] \
	[expr {$oldy * 65535 / $sy}] \
	{ABSOLUTE MOVE}
}


# ::winapi::__KillProcessThread -- Nicely quit process' threads
#
#	This command will post the WM_CLOSE message to all the threads
#	that are owned by a given process.
#
# Arguments:
#	pid	Process identifier
#
# Results:
#	None.
#
# Side Effects:
#	The process is likely not to exist after the command, since a
#	well-behave process should react by quiting.
proc ::winapi::__KillProcessThread { pid } {
    variable log

    set h [::winapi::CreateToolhelp32Snapshot SNAPTHREAD 0]
    if { $h < 0 } {
	${log}::warning "Could not create thread snapshot"
    }
    
    set nfo [::winapi::Thread32First $h]
    while { $nfo ne "" } {
	array set info $nfo
	if { $pid == $info(OwnerProcessID) } {
	    PostThreadMessage $info(ThreadID) WM_CLOSE 0 0
	}
	set nfo [::winapi::Thread32Next $h]
    }
    ::winapi::CloseHandle $h
}


# ::winapi::KillProcess -- Kill a process
#
#	This procedure attempts to kill a process is what is to
#	believe a gentle manner: It sends a WM_CLOSE message to all
#	the threads of the process, in the hope that the main thread
#	will react and terminate the process. Therefor, it waits for a
#	short period of time to detect if the process has finalised.
#	If not, it terminates it the hard way.
#
# Arguments:
#	pid	Identifier of process
#	code	Exit code
#	tmout	How long to wait before terminating it, negative to terminate
#               at once.
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::winapi::KillProcess { pid { tmout 1000 } {code 0} } {
    variable log

    set h [OpenProcess [list TERMINATE QUERY_INFORMATION] off $pid]
    if { $tmout <= 0 } {
	TerminateProcess $h $code
    } else {
	__KillProcessThread $pid
	WaitForSingleObject $h $tmout
	if { [GetExitCodeProcess $h] == "STILL_ACTIVE" } {
	    ${log}::debug "Process $pid still active, terminating it"
	    TerminateProcess $h $code
	}
    }
    CloseHandle $h
}


package provide winapix 0.3
