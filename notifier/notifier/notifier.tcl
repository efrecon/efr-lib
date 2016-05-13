# notifier.tcl -- Animated NOTIFIER
#
#	This implements an (animated) notifier that pop ups from one
#	of the sides of the screen a direction that can be chosen.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tk
package require logger

namespace eval ::notifier {
    # Initialise the global state
    variable NOTIF
    if {![::info exists NOTIF]} {
	array set NOTIF {
	    notifiers    ""
	    idgene       0
	    loglevel     warn
	    idgene       0
	    -anchor      se
	    -animate     left
	    -withdraw    on
	    -offsetx     0
	    -offsety     0
	    -keyframes   { 2000 5000 1500 }
	    -manual      off
	    -animation   50
	}
	variable log [::logger::init [string trimleft [namespace current] ::]]
	${log}::setlevel $NOTIF(loglevel)
    }

    namespace export loglevel new defaults
}


# ::notifier::loglevel -- Set/Get current log level.
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
proc ::notifier::loglevel { { loglvl "" } } {
    variable NOTIF
    variable log

    if { $loglvl != "" } {
	if { [catch "${log}::setlevel $loglvl"] == 0 } {
	    set NOTIF(loglevel) $loglvl
	}
    }

    return $NOTIF(loglevel)
}


# ::notifier::__validate -- Validate anchoring against direction
#
#	This procedure checks that the anchor specified for the
#	notifier is actually compatible with the direction of the
#	animation.
#
# Arguments:
#	top	Window name of the notifier.
#
# Results:
#	1 if anchoring and direction are compatible, 0 otherwise.
#
# Side Effects:
#	None.
proc ::notifier::__validate { top } {
    variable NOTIF
    variable log

    set idx [lsearch $NOTIF(notifiers) $top]
    if { $idx >= 0 } {
	set varname ::notifier::notifier_${top}
	upvar \#0 $varname NF
	
	set valid [list]
	set anchor [string tolower $NF(-anchor)]
	if { [string first "n" $anchor] } {
	    lappend valid down
	}
	if { [string first "e" $anchor] } {
	    lappend valid left
	}
	if { [string first "s" $anchor] } {
	    lappend valid up
	}
	if { [string first "w" $anchor] } {
	    lappend valid right
	}

	set animate [string tolower $NF(-animate)]
	if { [lsearch $animate $valid] >= 0 } {
	    return 1
	}
    }

    return 0
}


# ::notifier::__initpos -- Compute initial position
#
#	This procedure computes the initial position of a notifier
#       from all its arguments and state.
#
# Arguments:
#	top	Window name of the notifier
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::notifier::__initpos { top } {
    variable NOTIF
    variable log

    set idx [lsearch $NOTIF(notifiers) $top]
    if { $idx >= 0 } {
	set varname ::notifier::notifier_${top}
	upvar \#0 $varname NF
	
	if { [__validate $top] } {
	    ${log}::warn "$NF(-anchor) and $NF(-animate) are incompatible!"
	    set NF(timer) ""
	    return 
	}

	# Screen size
	set sw [winfo screenwidth $top]
	set sh [winfo screenheight $top]
	# Center of screen
	set csx [expr {$sw / 2}]
	set csy [expr {$sh / 2}]
	# Widget size
	set w [winfo width $top]
	set h [winfo height $top]
	# Widget center (relative) to top left corner
	set cx [expr {$w / 2}]
	set cy [expr {$h / 2}]
	switch [string tolower $NF(-anchor)] {
	    "n" {
		set NF(startx) [expr $csx - $cx + $NF(-offsetx)]
		set NF(starty) [expr -$h + $NF(-offsety)]
		set NF(endx) $NF(startx)
		set NF(endy) $NF(-offsety)
	    }
	    "ne" {
		if { [string tolower $NF(-animate)] == "down" } {
		    set NF(startx) [expr $sw - $w + $NF(-offsetx)]
		    set NF(starty) [expr -$h + $NF(-offsety)]
		    set NF(endx) $NF(startx)
		    set NF(endy) $NF(-offsety)
		} else {
		    set NF(startx) [expr $sw - $NF(-offsetx)]
		    set NF(starty) [expr $NF(-offsety)]
		    set NF(endx) [expr $sw - $w - $NF(-offsetx)]
		    set NF(endy) $NF(starty)
		}
	    }
	    "e" {
		set NF(startx) [expr $sw + $NF(-offsetx)]
		set NF(starty) [expr $csy - $cy + $NF(-offsety)]
		set NF(endx) [expr $sw - $w + $NF(-offsetx)]
		set NF(endy) $NF(starty)
	    }
	    "se" {
		if { [string tolower $NF(-animate)] == "left" } {
		    set NF(startx) [expr $sw + $NF(-offsetx)]
		    set NF(starty) [expr $sh - $h + $NF(-offsety)]
		    set NF(endx) [expr $sw - $w + $NF(-offsetx)]
		    set NF(endy) $NF(starty)
		} else {
		    set NF(startx) [expr $sw - $w + $NF(-offsetx)]
		    set NF(starty) [expr $sh + $NF(-offsety)]
		    set NF(endx) $NF(startx)
		    set NF(endy) [expr $sh - $h + $NF(-offsety)]
		}
	    }
	    "s" {
		set NF(startx) [expr $csx - $cx + $NF(-offsetx)]
		set NF(starty) [expr $sh + $NF(-offsety)]
		set NF(endx) $NF(startx)
		set NF(endy) [expr $sh - $h + $NF(-offsety)]
	    }
	    "sw" {
		if { [string tolower $NF(-animate)] == "up" } {
		    set NF(startx) [expr $NF(-offsetx)]
		    set NF(starty) [expr $sh + $NF(-offsety)]
		    set NF(endx) $NF(startx)
		    set NF(endy) [expr $sh - $h + $NF(-offsety)]
		} else {
		    set NF(startx) [expr -$w + $NF(-offsetx)]
		    set NF(starty) [expr $sh - $cy + $NF(-offsety)]
		    set NF(endx) $NF(-offsetx)
		    set NF(endy) $NF(starty)
		}
	    }
	    "w" {
		set NF(startx) [expr -$w + $NF(-offsetx)]
		set NF(starty) [expr $csy - $cy + $NF(-offsety)]
		set NF(endx) $NF(-offsetx)
		set NF(endy) $NF(starty)
	    }
	    "nw" {
		if { [string tolower $NF(-animate)] == "right" } {
		    set NF(startx) [expr -$w + $NF(-offsetx)]
		    set NF(starty) [expr $NF(-offsety)]
		    set NF(endx) $NF(-offsetx)
		    set NF(endy) $NF(starty)
		} else {
		    set NF(startx) [expr $NF(-offsetx)]
		    set NF(starty) [expr -$h + $NF(-offsety)]
		    set NF(endx) $NF(startx)
		    set NF(endy) $NF(-offsety)
		}
	    }
	}

	# Position the notifier on screen
	wm deiconify $NF(top)
	wm geometry $NF(top) +$NF(startx)+$NF(starty)

	update idletasks
    }
}


# ::notifier::__animate -- Performs one animation step
#
#	This procedure performs one animation step for the notifier
#	and automatically changes state whenever necessary.
#
# Arguments:
#	top	Window name of the notifier
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::notifier::__animate { top { stopat "" } } {
    variable NOTIF
    variable log

    set idx [lsearch $NOTIF(notifiers) $top]
    if { $idx >= 0 } {
	set varname ::notifier::notifier_${top}
	upvar \#0 $varname NF
	
	if { [__validate $top] } {
	    ${log}::warn "$NF(-anchor) and $NF(-animate) are incompatible!"
	    set NF(timer) ""
	    return 
	}
	switch $NF(state) {
	    "HIDDEN" {
		wm deiconify $top
		update idletasks
		__initpos $top
		set NF(startanim) [clock clicks -milliseconds]
		set NF(state) "SHOWING"
	    }
	    "SHOWING" {
		set now [clock clicks -milliseconds]
		set elapsed [expr {$now - $NF(startanim)}]
		set sp [lindex $NF(-keyframes) 0]
		if { $elapsed >= $sp } {
		    set x $NF(endx)
		    set y $NF(endy)
		    set NF(startanim) $now
		    set NF(state) "SHOWN"
		} else {
		    set x [expr {int($elapsed \
					 * (double($NF(endx) \
						     - $NF(startx))/$sp)) \
				     + $NF(startx)}]
		    set y [expr {int($elapsed \
					 * (double($NF(endy) \
						       - $NF(starty))/$sp)) \
				     + $NF(starty)}]
		}
		wm deiconify $NF(top)
		wm geometry $NF(top) +$x+$y
	    }
	    "SHOWN" {
		set now [clock clicks -milliseconds]
		set elapsed [expr {$now - $NF(startanim)}]
		set sp [lindex $NF(-keyframes) 1]
		if { $sp == "" } { set sp [lindex $NF(-keyframes) 0] }
		if { $elapsed >= $sp } {
		    set NF(startanim) $now
		    set NF(state) "HIDING"
		}
		set x $NF(endx)
		set y $NF(endy)
		wm deiconify $NF(top)
		wm geometry $NF(top) +$x+$y
	    }
	    "HIDING" {
		set now [clock clicks -milliseconds]
		set elapsed [expr {$now - $NF(startanim)}]
		set sp [lindex $NF(-keyframes) 2]
		if { $sp == "" } { set sp [lindex $NF(-keyframes) 1] }
		if { $sp == "" } { set sp [lindex $NF(-keyframes) 0] }
		if { $elapsed >= $sp } {
		    if { [string is true $NF(-withdraw)] } {
			wm withdraw $NF(top)
		    }
		    set NF(state) "HIDDEN"
		} else {
		    set x [expr {int($elapsed \
					 * (double($NF(startx) \
						       - $NF(endx))/$sp)) \
				     + $NF(endx)}]
		    set y [expr {int($elapsed \
					 * (double($NF(starty) \
						       - $NF(endy))/$sp)) \
				     + $NF(endy)}]
		    wm deiconify $NF(top)
		    wm geometry $NF(top) +$x+$y
		}
	    }
	}

	if { $NF(state) == "HIDDEN" } {
	    set NF(timer) ""
	} else {
	    if { $NF(state) == $stopat } {
		set NF(timer) ""
	    } else {
		set NF(timer) \
		    [after $NF(-animation) ::notifier::__animate $top $stopat]
	    }
	}
    }
}


# ::notifier::__hide -- Hide a notifier
#
#	This procedure will arrange to hide a notifier
#
# Arguments:
#	top	Top window.
#	atonce	If on, immediate removal from screen otherwise animation.
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::notifier::__hide { top { atonce off } } {
    variable NOTIF
    variable log

    set idx [lsearch $NOTIF(notifiers) $top]
    if { $idx >= 0 } {
	set varname ::notifier::notifier_${top}
	upvar \#0 $varname NF

	if { $NF(timer) != "" } {
	    after cancel $NF(timer)
	    set NF(timer) ""
	}

	if { [string is true $atonce] } {
	    # Hide at once.
	    ${log}::info "Hiding notifier $top at once"
	    set NF(state) "HIDDEN"
	    if { [string is true $NF(-withdraw)] } {
		wm withdraw $NF(top)
	    } else {
		__initpos $top
	    }
	    #update idletasks
	} elseif { $NF(state) != "HIDDEN" } {
	    # Force the state to be "SHOWN" and animate the notifier
	    # until it gets hidden, when in the "SHOWN" state the
	    # notifier will make the necessary time computations for
	    # the hiding animation.
	    ${log}::info "Hiding notifier $top with animation"
	    set NF(state) "SHOWN"
	    set NF(startanim) 0
	    ::notifier::__animate $top "HIDDEN"
	}
    } else {
	${log}::warn "notifier $top is not valid"
	return -code error "Identifier invalid"
    }
}


# ::notifier::__show -- Show a notifier
#
#	This procedure will arrange to show a notifier.  Automatic
#	notifiers will be shown for a given period of time and
#	automatically disappear.  Manual notifiers will be shown and
#	users will have to call the 'hide' command to make them hide.
#
# Arguments:
#	top	Top window.
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::notifier::__show { top } {
    variable NOTIF
    variable log

    set idx [lsearch $NOTIF(notifiers) $top]
    if { $idx >= 0 } {
	set varname ::notifier::notifier_${top}
	upvar \#0 $varname NF

	${log}::info "Showing notifier $top"
	if { $NF(state) != "HIDDEN" } {
	    __hide $top on
	}

	if { [string is true $NF(-manual)] } {
	    ::notifier::__animate $top "SHOWN"
	} else {
	    ::notifier::__animate $top
	}
    } else {
	${log}::warn "notifier $top is not valid"
	return -code error "Identifier invalid"
    }
}

proc ::notifier::__state { top } {
    variable NOTIF
    variable log

    set idx [lsearch $NOTIF(notifiers) $top]
    if { $idx >= 0 } {
	set varname ::notifier::notifier_${top}
	upvar \#0 $varname NF

	return $NF(state)
    }
}


proc ::notifier::__delete { top } {
    variable NOTIF
    variable log

    set idx [lsearch $NOTIF(notifiers) $top]
    if { $idx >= 0 } {
	set varname ::notifier::notifier_${top}
	upvar \#0 $varname NF

	if { $NF(timer) != "" } {
	    after cancel $NF(timer)
	}
	
	set NOTIF(notifiers) [lreplace $NOTIF(notifiers) $idx $idx]
	unset NF
    }
}


# ::notifier::new -- Create a new NOTIF
#
#	This command creates a new NOTIF that will be shown as a
#	toplevel window.  The toplevel is withdrawn at once.
#
# Arguments:
#	top	Name of top level window
#	args	Additional -key value attributes, see top of file
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::notifier::new { args } {
    variable NOTIF
    variable log

    if  { [string match "-*" [lindex $args 0]] || [llength $args] == 0 } {
	# Generate a name for the toplevel that does not exist.
	for { set top ".notifier$NOTIF(idgene)" } \
	    { [winfo exist $top] } { incr NOTIF(idgene) } {
	    set top ".notifier$NOTIF(idgene)"
	}
    } else {
	set top [lindex $args 0]
	set args [lrange $args 1 end]
    }

    set idx [lsearch $NOTIF(notifiers) $top]
    if { $idx < 0 } {
	set varname ::notifier::notifier_${top}
	upvar \#0 $varname NF

	set NF(top) $top
	set NF(state) "HIDDEN"
	set NF(timer) ""
	lappend NOTIF(notifiers) $top

	foreach opt [array names NOTIF "-*"] {
	    set NF($opt) $NOTIF($opt)
	}
	toplevel $top
	if { [string is true $NF(-withdraw)] } {
	    wm withdraw $top
	}
	wm overrideredirect $top 1
	update idletasks
	rename ::$top ::notifier::$top
	proc ::$top { cmd args } [string map [list @w@ ::notifier::$top] {
	    set w [namespace tail [lindex [info level 0] 0]]
	    switch -- $cmd {
		config -
		configure {eval ::notifier::__config $w $args}
		show {::notifier::__show $w}
		hide {eval ::notifier::__hide $w off}
		state {eval ::notifier::__state $w}
		withdraw {::notifier::__hide $w on}
		default {eval @w@ $cmd $args}
	    }
	}]
	bind $top <Destroy> +[list ::notifier::__delete $top]
	${log}::debug "Created new notifier $top"
    }
    eval __config $top $args

    return $top
}


# ::notifier::__lpick -- Pick n'th index in a list of lists
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
proc ::notifier::__lpick { l i } {
    set out [list]
    foreach item $l {
	lappend out [lindex $item $i]
    }

    return $out
}


# ::notifier::__config -- Configure an NOTIF
#
#	This command set or get the options of an NOTIF
#
# Arguments:
#	top	Toplevel identifying the (known) NOTIF
#	args	list of options
#
# Results:
#	Return all options, the option requested or set the options
#
# Side Effects:
#	None.
proc ::notifier::__config { top args } {
    variable NOTIF
    variable log

    # Check that this is one of our connections
    set idx [lsearch $NOTIF(notifiers) $top]
    if { $idx < 0 } {
	${log}::warn "notifier $top is not valid"
	return -code error "Identifier invalid"
    }

    set varname "::notifier::notifier_${top}"
    upvar \#0 $varname NF

    set o [lsort [array names NF "-*"]]
    set to [__lpick [::notifier::$top configure] 0]

    if { [llength $args] == 0 } {      ;# Return all results
	set result ""
	foreach name $o {
	    lappend result $name $NF($name)
	}
	foreach name $to {
	    lappend result $name [::notifier::$top cget $name]
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
		return $NF($opt)
	    } else {
		return [::notifier::$top cget $opt]
	    }
	}
	if { [lsearch $o $opt] >= 0 } {
	    set NF($opt) $value          ;# Set the config value
	} else {
	    ::notifier::$top configure $opt $value
	}
    }
}


# ::notifier::defaults -- Set/Get defaults for all new viewers
#
#	This command sets or gets the defaults options for all new
#	monitoring, it will not perpetrate on existing pending
#	connections, use ::notifier::config instead.
#
# Arguments:
#	args	List of -key value or just -key to get value
#
# Results:
#	Return all options, the option requested or set the options
#
# Side Effects:
#	None.
proc ::notifier::defaults { args } {
    variable NOTIF
    variable log

    set o [lsort [array names NOTIF "-*"]]

    if { [llength $args] == 0 } {      ;# Return all results
	set result ""
	foreach name $o {
	    lappend result $name $NOTIF($name)
	}
	return $result
    }

    foreach {opt value} $args {        ;# Get one or set some
	if { [lsearch $o $opt] == -1 } {
	    return -code error "Unknown option $opt, must be: [join $o ,]"
	}
	if { [llength $args] == 1 } {  ;# Get one config value
	    return $NOTIF($opt)
	}
	set NOTIF($opt) $value           ;# Set the config value
    }
}


package provide notifier 0.2
