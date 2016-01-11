# floatingbbar.tcl -- Animated on-screen display
#
#	This implements an (animated) auto-windows floatingbbar.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tk
package require logger
package require notifier

namespace eval ::floatingbbar {
    # Initialise the global state
    variable BBAR
    if {![::info exists BBAR]} {
	array set BBAR {
	    floatingbbars         ""
	    idgene       0
	    loglevel     warn
	    -side        "right"
	    -bg          "white"
	    -pad         5
	    -content     ""
	}
	variable log [::logger::init [string trimleft [namespace current] ::]]
	${log}::setlevel $BBAR(loglevel)
    }

    namespace export loglevel new defaults
}


# ::floatingbbar::loglevel -- Set/Get current log level.
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
proc ::floatingbbar::loglevel { { loglvl "" } } {
    variable BBAR
    variable log

    if { $loglvl != "" } {
	if { [catch "${log}::setlevel $loglvl"] == 0 } {
	    set BBAR(loglevel) $loglvl
	}
    }

    return $BBAR(loglevel)
}


# ::floatingbbar::__draw -- Draw or actualise content of widget
#
#	This procedure (re)draws the content of a BBAR top level
#	widget.  The content of the widget is destroyed before being
#	redrawn if it existed.  The widget will contain a placeholder
#	for an image (possibly empty) and a text.
#
# Arguments:
#	top	Top window.
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::floatingbbar::__draw { top } {
    variable BBAR
    variable log

    # Check that this is one of our connections
    set idx [lsearch $BBAR(floatingbbars) $top]
    if { $idx >= 0 } {
	set varname "::floatingbbar::floatingbbar_${top}"
	upvar \#0 $varname floatingbbar
	
	# Remove content of previous top level window
	if { [winfo exists $top] } {
	    ::floatingbbar::$top configure -bg $floatingbbar(-bg)
	    foreach kid [winfo children $top] {
		delete $kid
	    }
	}
	
	set packside [string map [list "right" "bottom" \
				      "bottom" "left" \
				      "left" "top" \
				      "top" "right"] $floatingbbar(-side)]
	set len [llength $floatingbbar(images)]
	for { set i 0 } { $i < $len } { incr i } {
	    set img [lindex $floatingbbar(images) $i]
	    if { $img ne "" } {
		button ${top}.btn$i \
		    -image $img \
		    -bg $floatingbbar(-bg) \
		    -command [lindex $floatingbbar(-content) [expr 2*$i+1]]
		pack ${top}.btn$i -side $packside \
		    -padx $floatingbbar(-pad) \
		    -pady $floatingbbar(-pad) \
		    -fill both \
		    -expand on
	    }
	}
    }
}


# ::floatingbbar::new -- Create a new BBAR
#
#	This command creates a new BBAR that will be shown as a
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
proc ::floatingbbar::new { args } {
    variable BBAR
    variable log

    if  { [string match "-*" [lindex $args 0]] || [llength $args] == 0 } {
	# Generate a name for the toplevel that does not exist.
	for { set top ".floatingbbar$BBAR(idgene)" } \
	    { [winfo exist $top] } { incr BBAR(idgene) } {
	    set top ".floatingbbar$BBAR(idgene)"
	}
    } else {
	set top [lindex $args 0]
	set args [lrange $args 1 end]
    }

    set idx [lsearch $BBAR(floatingbbars) $top]
    if { $idx < 0 } {
	set varname ::floatingbbar::floatingbbar_${top}
	upvar \#0 $varname floatingbbar

	set floatingbbar(top) [::notifier::new $top]
	set floatingbbar(images) ""
	lappend BBAR(floatingbbars) $top

	foreach opt [array names BBAR "-*"] {
	    set floatingbbar($opt) $BBAR($opt)
	}
	rename ::$top ::floatingbbar::$top
	catch "wm attributes $top -topmost on"
	proc ::$top { cmd args } [string map [list @w@ ::floatingbbar::$top] {
	    set w [namespace tail [lindex [info level 0] 0]]
	    switch -- $cmd {
		config -
		configure {eval ::floatingbbar::__config $w $args}
		default {eval @w@ $cmd $args}
	    }
	}]
	bind $top <Destroy> +[list ::floatingbbar::__delete $top]
    }
    eval __config $top $args

    return $top
}



# ::floatingbbar::__lpick -- Pick n'th index in a list of lists
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
proc ::floatingbbar::__lpick { l i } {
    set out [list]
    foreach item $l {
	lappend out [lindex $item $i]
    }

    return $out
}


# ::floatingbbar::__displaycontrol -- Control bbar status
#
#	This procedure controls the display status of the floating
#	button bar and is bound to enter and leave events.
#
# Arguments:
#	top	Identifier of floating bbar
#	state	One of "show" or "hide"
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::floatingbbar::__displaycontrol { top state } {
    variable BBAR
    variable log

    # Check that this is one of our connections
    set idx [lsearch $BBAR(floatingbbars) $top]
    if { $idx < 0 } {
	${log}::warn "floatingbbar $top is not valid"
	return -code error "Identifier invalid"
    }

    set varname "::floatingbbar::floatingbbar_${top}"
    upvar \#0 $varname floatingbbar

    switch $state {
	"show" {
	    if { [::floatingbbar::$top state] == "HIDDEN" } {
		::floatingbbar::$top show
	    }
	}
	"hide" {
	    after 1000 ::floatingbbar::$top hide
	}
    }
}

# ::floatingbbar::__config -- Configure an BBAR
#
#	This command set or get the options of an BBAR
#
# Arguments:
#	top	Toplevel identifying the (known) BBAR
#	args	list of options
#
# Results:
#	Return all options, the option requested or set the options
#
# Side Effects:
#	None.
proc ::floatingbbar::__config { top args } {
    variable BBAR
    variable log

    # Check that this is one of our connections
    set idx [lsearch $BBAR(floatingbbars) $top]
    if { $idx < 0 } {
	${log}::warn "floatingbbar $top is not valid"
	return -code error "Identifier invalid"
    }

    set varname "::floatingbbar::floatingbbar_${top}"
    upvar \#0 $varname floatingbbar

    set o [lsort [array names floatingbbar "-*"]]
    set to [__lpick [::floatingbbar::$top configure] 0]

    if { [llength $args] == 0 } {      ;# Return all results
	set result ""
	foreach name $o {
	    lappend result $name $floatingbbar($name)
	}
	foreach name $to {
	    lappend result $name [::floatingbbar::$top configure $name]
	}
	return $result
    }

    set oldcnt $floatingbbar(-content)
    foreach {opt value} $args {        ;# Get one or set some
	if { [lsearch $o $opt] == -1 && [lsearch $to $opt] == -1 } {
	    return -code error \
		"Unknown option $opt, must be: [join $o ", " ], [join $to ", "]"
	}
	if { [llength $args] == 1 } {  ;# Get one config value
	    if { [lsearch $o $opt] >= 0 } {
		return $floatingbbar($opt)
	    } else {
		return [::floatingbbar::$top configure $opt]
	    }
	}
	if { [lsearch $o $opt] >= 0 } {
	    set floatingbbar($opt) $value          ;# Set the config value
	} else {
	    ::floatingbbar::$top configure $opt $value
	}
    }

    set offsetx 0
    set offsety 0
    switch $floatingbbar(-side) {
	"right" {
	    set offsetx [expr -$floatingbbar(-pad)]
	    set offsety 0
	    set anchor e
	    set animate left
	}
	"left" {
	    set offsetx [expr $floatingbbar(-pad)]
	    set offsety 0
	    set anchor w
	    set animate right
	}
	"top" {
	    set offsetx 0
	    set offsety [expr $floatingbbar(-pad)]
	    set anchor n
	    set animate down
	}
	"bottom" {
	    set offsetx 0
	    set offsety [expr -$floatingbbar(-pad)]
	    set anchor s
	    set animate up
	}
    }
    ::floatingbbar::$top configure -withdraw off \
	-offsetx $offsetx -offsety $offsety -anchor $anchor -animate $animate \
	-manual on
    bind $top <Enter> [list ::floatingbbar::__displaycontrol $top show]
    bind $top <Leave> [list ::floatingbbar::__displaycontrol $top hide]


    # (remove) and load (new) image
    if { $oldcnt != $floatingbbar(-content) } {
	if { $floatingbbar(images) ne "" } {
	    foreach img $floatingbbar(images) {
		image delete $img
	    }
	    set floatingbbar(images) ""
	}
	foreach {fname cmd} $floatingbbar(-content) {
	    if { [catch {image create photo -file $fname} img] } {
		${log}::warn "Could not load image at $floatingbbar(-image)"
		lappend floatingbbar(images) ""
	    } else {
		lappend floatingbbar(images) "$img"
	    }
	}
    }

    __draw $top
}


# ::floatingbbar::__delete -- Destruction callback
#
#	This procedure is bound to the window destruction callback and
#	clean the resources used by the floating bbar being destroyed.
#
# Arguments:
#	top	Identifier of the floating bbar
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::floatingbbar::__delete { top } {
    variable BBAR
    variable log

    # Check that this is one of our floating bbars
    set idx [lsearch $BBAR(floatingbbars) $top]
    if { $idx >= 0 } {
	set varname "::floatingbbar::floatingbbar_${top}"
	upvar \#0 $varname floatingbbar
	
	# Remove images.
	foreach img $floatingbbar(images) {
	    image delete $img
	}
	set BBAR(floatingbbars) [lreplace $BBAR(floatingbbars) $idx $idx]
	unset floatingbbar
    }
}


# ::floatingbbar::defaults -- Set/Get defaults for all new viewers
#
#	This command sets or gets the defaults options for all new
#	monitoring, it will not perpetrate on existing pending
#	connections, use ::floatingbbar::config instead.
#
# Arguments:
#	args	List of -key value or just -key to get value
#
# Results:
#	Return all options, the option requested or set the options
#
# Side Effects:
#	None.
proc ::floatingbbar::defaults { args } {
    variable BBAR
    variable log

    set o [lsort [array names BBAR "-*"]]

    if { [llength $args] == 0 } {      ;# Return all results
	set result ""
	foreach name $o {
	    lappend result $name $BBAR($name)
	}
	return $result
    }

    foreach {opt value} $args {        ;# Get one or set some
	if { [lsearch $o $opt] == -1 } {
	    return -code error "Unknown option $opt, must be: [join $o ,]"
	}
	if { [llength $args] == 1 } {  ;# Get one config value
	    return $BBAR($opt)
	}
	set BBAR($opt) $value           ;# Set the config value
    }
}


package provide floatingbbar 0.1
