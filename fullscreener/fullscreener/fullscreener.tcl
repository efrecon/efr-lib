# fullscreen.tcl -- Fullscreen framer
#
#	This module sees to keep existing windows in front of a
#	fullscreen blank frame.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tk
package require winapi

namespace eval ::fullscreener {
    # Initialise the global state
    variable FS
    if {![::info exists FS]} {
	array set FS {
	    wins         ""
	    loglevel     warn
	    idgene       0
	    -centered    "on"
	    -period      50
	}
	variable log [::logger::init [string trimleft [namespace current] ::]]
	${log}::setlevel $FS(loglevel)
    }

    namespace export loglevel frame
}


# ::fullscreener::loglevel -- Set/Get current log level.
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
proc ::fullscreener::loglevel { { loglvl "" } } {
    variable FS
    variable log

    if { $loglvl != "" } {
	if { [catch "${log}::setlevel $loglvl"] == 0 } {
	    set FS(loglevel) $loglvl
	}
    }

    return $FS(loglevel)
}



# ::fullscreener::__keep -- Keep attached window in position
#
#	This command arranges to watch the window that is attached to
#	the fullscreen widget so that it is kept in position (if
#	centered) and at the front all time.  The command
#	automatically detach the window from the fullscreen widget as
#	soon as the window stops to exist.
#
# Arguments:
#	top	Identifier of fullscreen top level
#
# Results:
#	None.
#
# Side Effects:
#	Will force attached window to position
proc ::fullscreener::__keep { top { force off } } {
    variable FS
    variable log

    set idx [lsearch $FS(wins) $top]
    if { $idx >= 0 } {
	set varname ::fullscreener::fullscreen_${top}
	upvar \#0 $varname fullscreen

	if { [::winapi::IsWindow $fullscreen(win)] \
		 && [::winapi::IsWindowVisible $fullscreen(win)] } {
	    # The attached window is still there, place it whereever
	    # it should be.  Note that IsWindow is unsafe really since
	    # window identifiers are reused in Windows.
	    if { [string is true $fullscreen(-centered)] } {
		# if the window should be centered, position it at the
		# center of the screen if it has moved, seeing to
		# activate it.  Otherwise, keep it in front through
		# activating it.
		set sw [winfo screenwidth $top]
		set sh [winfo screenheight $top]
		set rect [::winapi::GetWindowRect $fullscreen(win)]
		set w [expr [lindex $rect 2] - [lindex $rect 0]]
		set h [expr [lindex $rect 3] - [lindex $rect 1]]
		set x [expr ($sw-$w)/2]
		if { $x < 0 } { set x 0 }
		set y [expr ($sh-$h)/2]
		if { $y < 0 } { set y 0 }
		if { [lindex $rect 0] != $x || [lindex $rect 1] != $y \
			 || [string is true $force] \
			 || [::winapi::GetForegroundWindow] \
			 != $fullscreen(win)} {
		    ${log}::debug \
			"Attached window has moved/lost focus, recentering"
		    ::winapi::SetWindowPos $fullscreen(win) 0 \
			$x $y -1 -1 [list SWP_NOSIZE SWP_ASYNCWINDOWPOS]
		}
	    } else {
		# Keep it in front of other windows through keeping to
		# activate the attached window all the time.
		if { [::winapi::GetForegroundWindow] != $fullscreen(win) \
			 || [string is true $force] } {
		    ${log}::debug "Attached window is not in front, focusing"
		    ::winapi::SetWindowPos $fullscreen(win) 0
		}
	    }
	    # Reschedule next check
	    set fullscreen(checkid) \
		[after $fullscreen(-period) ::fullscreener::__keep $top]
	} else {
	    # Detach the window.
	    ${log}::info \
		"Attached window $fullscreen(win) has disappeared, detaching"
	    set fullscreen(checkid) ""
	    __detach $top
	}
    }
}



# ::fullscreener::__attach -- Attach a window to a fullscreen widget
#
#	This command arranges to attach any other window to a
#	fullscreener widget.  The window will be kept in front of all
#	other windows (but not topmost though) and centered around the
#	fullscreener if necessary.  If no window identifier is
#	provided, the command attaches to the current foreground
#	window.
#
# Arguments:
#	top	Top level identifier of the fullscreener
#	args	Identifier of the window to put fullscreen
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::fullscreener::__attach { top args } {
    variable FS
    variable log

    set idx [lsearch $FS(wins) $top]
    if { $idx >= 0 } {
	set varname ::fullscreener::fullscreen_${top}
	upvar \#0 $varname fullscreen

	# Decide upon the window to attach to
	if { [llength $args] == 0 } {
	    set topwin [::winapi::GetForegroundWindow]
	    ${log}::debug "Attaching to foreground window: $topwin"
	} else {
	    set winid [lindex $args 0]
	    if { [winfo exists $winid] } {
		set topwin [winfo toplevel $winid]
		#set topwin [::winapi::GetAncestor [winfo id $topwin] GA_ROOT]
		set topwin [winfo id $topwin]
		${log}::debug "Attaching to tk window $winid: $topwin"
	    } else {
		set topwin [expr $winid]
		${log}::debug "Attaching to external window: $topwin"
	    }
	}
	if { $fullscreen(win) ne "" } {
	    __detach $top
	}
	set fullscreen(win) $topwin

	if { [winfo exists $top] } {
	    set sw [winfo screenwidth $top]
	    set sh [winfo screenheight $top]
	    ::fullscreener::$top configure -width $sw -height $sh
	    foreach sw [winfo children $top] { destroy $sw }
	} else {
	    set sw [winfo screenwidth .]
	    set sh [winfo screenheight .]
	    toplevel $top -width $sw -height $sh
	}

	wm overrideredirect $top 1
	wm geometry $top ${sw}x${sh}+0+0
	wm deiconify $top
	
	set fullscreen(checkid) [after idle ::fullscreener::__keep $top on]
    }
}


# ::fullscreener::__detach -- Detach currently attached window
#
#	This command will detach the currently attached window and see
#	to hide the fullscreener widget again.
#
# Arguments:
#	top	Identifier of the toplevel fullscreener
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::fullscreener::__detach { top } {
    variable FS
    variable log

    set idx [lsearch $FS(wins) $top]
    if { $idx >= 0 } {
	set varname ::fullscreener::fullscreen_${top}
	upvar \#0 $varname fullscreen

	${log}::debug "Detaching from current window $fullscreen(win)"
	if { $fullscreen(checkid) != "" } {
	    after cancel $fullscreen(checkid)
	}
	set fullscreen(checkid) ""
	set fullscreen(win) ""
	wm withdraw $top
    }
}



# ::fullscreener::new -- Create a new fullscreener
#
#	This command creates a new fullscreener (which is implemented
#	as an empty toplevel widget).  The fullscreener will be shown
#	when it is attached to a window with the attach command.
#
# Arguments:
#	top	Name of top level to create (empty for autogenerated)
#	args	Additional -key value attributes, see top of file
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::fullscreener::new { args } {
    variable FS
    variable log

    if  { [string match "-*" [lindex $args 0]] || [llength $args] == 0 } {
	# Generate a name for the toplevel that does not exist.
	for { set top ".fullscreen$FS(idgene)" } \
	    { [winfo exist $top] } { incr FS(idgene) } {
	    set top ".fullscreen$FS(idgene)"
	}
    } else {
	set top [lindex $args 0]
	set args [lrange $args 1 end]
    }

    set idx [lsearch $FS(wins) $top]
    if { $idx < 0 } {
	set varname ::fullscreener::fullscreen_${top}
	upvar \#0 $varname fullscreen

	set fullscreen(win) ""
	set fullscreen(checkid) ""
	lappend FS(wins) $top

	foreach opt [array names FS "-*"] {
	    set fullscreen($opt) $FS($opt)
	}
	toplevel $top
	wm withdraw $top
	wm overrideredirect $top 1
	rename ::$top ::fullscreener::$top
	proc ::$top { cmd args } [string map [list @w@ ::fullscreener::$top] {
	    set w [namespace tail [lindex [info level 0] 0]]
	    switch -- $cmd {
		config -
		configure {eval ::fullscreener::__config $w $args}
		attach {eval ::fullscreener::__attach $w $args}
		detach {eval ::fullscreener::__detach $w}
		default {eval @w@ $cmd $args}
	    }
	}]
    }
    eval __config $top $args

    return $top
}


# ::fullscreener::__lpick -- Pick n'th index in a list of lists
#
#	This procedure considers the list passed as argument as a list
#	of lists and returns back a list containing the n'th element
#	of each sub list.
#
# Arguments:
#	l	Input list of lists.
#	i	Index of elements to pick in sub lists.
#
# Results:
#	A list of all i'th index in the sub lists.
#
# Side Effects:
#	None.
proc ::fullscreener::__lpick { l i } {
    set out [list]
    foreach item $l {
	lappend out [lindex $item $i]
    }

    return $out
}


# ::fullscreener::__config -- Configure an FS
#
#	This command set or get the options of an FS
#
# Arguments:
#	top	Toplevel identifying the (known) FS
#	args	list of options
#
# Results:
#	Return all options, the option requested or set the options
#
# Side Effects:
#	None.
proc ::fullscreener::__config { top args } {
    variable FS
    variable log

    # Check that this is one of our connections
    set idx [lsearch $FS(wins) $top]
    if { $idx < 0 } {
	${log}::warn "fullscreen $top is not valid"
	return -code error "Identifier invalid"
    }

    set varname "::fullscreener::fullscreen_${top}"
    upvar \#0 $varname fullscreen

    set o [lsort [array names fullscreen "-*"]]
    set to [__lpick [::fullscreener::$top configure] 0]

    if { [llength $args] == 0 } {      ;# Return all results
	set result ""
	foreach name $o {
	    lappend result $name $fullscreen($name)
	}
	foreach name $to {
	    lappend result $name [::fullscreener::$top cget $name]
	}
	return $result
    }

    foreach {opt value} $args {        ;# Get one or set some
	if { [lsearch $o $opt] == -1 && [lsearch $to $opt] == -1 } {
	    return -code error \
		"Unknown option $opt, must be: [join $o ", " ], [join $to ", "]"
	}
	if { [llength $args] == 1 } {  ;# Get one config value
	    if { [lsearch $o $opt] >= 0 } {
		return $fullscreen($opt)
	    } else {
		return [::fullscreener::$top cget $opt]
	    }
	}
	if { [lsearch $o $opt] >= 0 } {
	    set fullscreen($opt) $value          ;# Set the config value
	} else {
	    ::fullscreener::$top configure $opt $value
	}
    }
}


# ::fullscreener::defaults -- Set/Get defaults for all new viewers
#
#	This command sets or gets the defaults options for all new
#	monitoring, it will not perpetrate on existing pending
#	connections, use ::fullscreener::config instead.
#
# Arguments:
#	args	List of -key value or just -key to get value
#
# Results:
#	Return all options, the option requested or set the options
#
# Side Effects:
#	None.
proc ::fullscreener::defaults { args } {
    variable FS
    variable log

    set o [lsort [array names FS "-*"]]

    if { [llength $args] == 0 } {      ;# Return all results
	set result ""
	foreach name $o {
	    lappend result $name $FS($name)
	}
	return $result
    }

    foreach {opt value} $args {        ;# Get one or set some
	if { [lsearch $o $opt] == -1 } {
	    return -code error "Unknown option $opt, must be: [join $o ,]"
	}
	if { [llength $args] == 1 } {  ;# Get one config value
	    return $FS($opt)
	}
	set FS($opt) $value           ;# Set the config value
    }
}

package provide fullscreener 0.1
