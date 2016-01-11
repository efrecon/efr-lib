# osd.tcl -- Animated on-screen display
#
#	This implements an (animated) on-screen display
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tk
package require logger
package require notifier

namespace eval ::osd {
    # Initialise the global state
    variable OSD
    if {![::info exists OSD]} {
	array set OSD {
	    osds         ""
	    idgene       0
	    loglevel     warn
	    -image       ""
	    -bg          "white"
	    -text        ""
	    -justify     "left"
	    -font        "Arial 32 bold"
	}
	variable log [::logger::init [string trimleft [namespace current] ::]]
	${log}::setlevel $OSD(loglevel)
    }

    namespace export loglevel new defaults
}


# ::osd::loglevel -- Set/Get current log level.
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
proc ::osd::loglevel { { loglvl "" } } {
    variable OSD
    variable log

    if { $loglvl != "" } {
	if { [catch "${log}::setlevel $loglvl"] == 0 } {
	    set OSD(loglevel) $loglvl
	}
    }

    return $OSD(loglevel)
}


# ::osd::__draw -- Draw or actualise content of widget
#
#	This procedure (re)draws the content of a OSD top level
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
proc ::osd::__draw { top } {
    variable OSD
    variable log

    # Check that this is one of our connections
    set idx [lsearch $OSD(osds) $top]
    if { $idx >= 0 } {
	set varname "::osd::osd_${top}"
	upvar \#0 $varname osd
	
	# Remove content of previous top level window
	if { [winfo exists $top] } {
	    ::osd::$top configure -bg $osd(-bg)
	}

	if { [winfo exists ${top}.img] } {
	    ${top}.img configure -image $osd(image) -bg $osd(-bg)
	    ${top}.txt configure -text $osd(-text) -justify $osd(-justify) \
		-font $osd(-font) -bg $osd(-bg)
	} else {
	    label ${top}.img -image $osd(image) -bg $osd(-bg)
	    label ${top}.txt -text $osd(-text) -justify $osd(-justify) \
		-font $osd(-font) -bg $osd(-bg)
	    pack ${top}.img -side left -fill y -expand on
	    pack ${top}.txt -side right -fill both -expand on
	}
	update idletasks
    }
}


# ::osd::new -- Create a new OSD
#
#	This command creates a new OSD that will be shown as a
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
proc ::osd::new { args } {
    variable OSD
    variable log

    if  { [string match "-*" [lindex $args 0]] || [llength $args] == 0 } {
	# Generate a name for the toplevel that does not exist.
	for { set top ".osd$OSD(idgene)" } \
	    { [winfo exist $top] } { incr OSD(idgene) } {
	    set top ".osd$OSD(idgene)"
	}
    } else {
	set top [lindex $args 0]
	set args [lrange $args 1 end]
    }

    set idx [lsearch $OSD(osds) $top]
    if { $idx < 0 } {
	set varname ::osd::osd_${top}
	upvar \#0 $varname osd

	set osd(top) [::notifier::new $top]
	set osd(image) ""
	lappend OSD(osds) $top

	foreach opt [array names OSD "-*"] {
	    set osd($opt) $OSD($opt)
	}
	rename ::$top ::osd::$top
	catch "wm attributes $top -topmost on"
	proc ::$top { cmd args } [string map [list @w@ ::osd::$top] {
	    set w [namespace tail [lindex [info level 0] 0]]
	    switch -- $cmd {
		config -
		configure {eval ::osd::__config $w $args}
		default {eval @w@ $cmd $args}
	    }
	}]
    }
    eval __config $top $args

    return $top
}



# ::osd::__lpick -- Pick n'th index in a list of lists
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
proc ::osd::__lpick { l i } {
    set out [list]
    foreach item $l {
	lappend out [lindex $item $i]
    }

    return $out
}


# ::osd::__config -- Configure an OSD
#
#	This command set or get the options of an OSD
#
# Arguments:
#	top	Toplevel identifying the (known) OSD
#	args	list of options
#
# Results:
#	Return all options, the option requested or set the options
#
# Side Effects:
#	None.
proc ::osd::__config { top args } {
    variable OSD
    variable log

    # Check that this is one of our connections
    set idx [lsearch $OSD(osds) $top]
    if { $idx < 0 } {
	${log}::warn "osd $top is not valid"
	return -code error "Identifier invalid"
    }

    set varname "::osd::osd_${top}"
    upvar \#0 $varname osd

    set o [lsort [array names osd "-*"]]
    set to [__lpick [::osd::$top configure] 0]

    if { [llength $args] == 0 } {      ;# Return all results
	set result ""
	foreach name $o {
	    lappend result $name $osd($name)
	}
	foreach name $to {
	    lappend result $name [::osd::$top configure $name]
	}
	return $result
    }

    set oldimg $osd(-image)
    foreach {opt value} $args {        ;# Get one or set some
	if { [lsearch $o $opt] == -1 && [lsearch $to $opt] == -1 } {
	    return -code error \
		"Unknown option $opt, must be: [join $o ", " ], [join $to ", "]"
	}
	if { [llength $args] == 1 } {  ;# Get one config value
	    if { [lsearch $o $opt] >= 0 } {
		return $osd($opt)
	    } else {
		return [::osd::$top configure $opt]
	    }
	}
	if { [lsearch $o $opt] >= 0 } {
	    set osd($opt) $value          ;# Set the config value
	} else {
	    ::osd::$top configure $opt $value
	}
    }

    # (remove) and load (new) image
    if { $oldimg != $osd(-image) } {
	if { $osd(image) != "" } {
	    image delete $osd(image)
	    set osd(image) ""
	}
	if { [catch {image create photo -file $osd(-image)} img] } {
	    ${log}::warn "Could not load image at $osd(-image)"
	} else {
	    set osd(image) $img
	}
    }

    __draw $top
}


# ::osd::defaults -- Set/Get defaults for all new viewers
#
#	This command sets or gets the defaults options for all new
#	monitoring, it will not perpetrate on existing pending
#	connections, use ::osd::config instead.
#
# Arguments:
#	args	List of -key value or just -key to get value
#
# Results:
#	Return all options, the option requested or set the options
#
# Side Effects:
#	None.
proc ::osd::defaults { args } {
    variable OSD
    variable log

    set o [lsort [array names OSD "-*"]]

    if { [llength $args] == 0 } {      ;# Return all results
	set result ""
	foreach name $o {
	    lappend result $name $OSD($name)
	}
	return $result
    }

    foreach {opt value} $args {        ;# Get one or set some
	if { [lsearch $o $opt] == -1 } {
	    return -code error "Unknown option $opt, must be: [join $o ,]"
	}
	if { [llength $args] == 1 } {  ;# Get one config value
	    return $OSD($opt)
	}
	set OSD($opt) $value           ;# Set the config value
    }
}


package provide osd 0.1
