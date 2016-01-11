# dragger.tcl -- Backend support for drag/drop of icons
#
#	This module provides the back end support for drag/drop of
#	icons.  It purpose is to follow mouse movements with icons
#	that may be shaped.  It allows to register any Tk widget path
#	as a drag source; on button press, an image icon (possibly
#	shaped) will be created and will follow the mouse cursor until
#	release of the button.  On button release, the library
#	delivers a callback.
#
# Copyright (c) 2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.4
package require Tk

package require uobj
package require imgop

namespace eval ::dragger {
    variable DRAGGER
    if { ! [info exists DRAGGER] } {
	array set DRAGGER {
	    tktrans        "TkTrans.dll"
	    shapecapable   0
	    sources        ""
	    idgene         0
	    -buttons       "1"
	    -drop          ""
	    -topmost       off
	    -indirector    ""
	}
	variable libdir [file dirname [file normalize [info script]]]
	::uobj::install_log dragger DRAGGER; # Creates log namespace variable
	::uobj::install_defaults dragger DRAGGER

	# Load the tktrans extension to allow for shape windows. We
	# load it under the dragger namespace (the default behaviour
	# of load it seems) to avoid polluting the main namespace
	# tree.  I am unsure whether this is a good idea.
	if { $::tcl_platform(platform) eq "windows" } {
	    set dll [file join $libdir "tktrans" $::tcl_platform(platform) \
			 $DRAGGER(tktrans)]
	    if { [catch {load $dll} res] == 0 } {
		set DRAGGER(shapecapable) 1
	    } else {
		error "Could not load TkTrans dll from $dll"
	    }
	}
    }
}


# ::dragger::__destroydragger -- Destroy dragged image
#
#	This procedure destroys a dragged image and restore the
#	original bindings that were associated to the window from
#	which the image was dragged, if any.
#
# Arguments:
#	w	Path to dragger source
#	buttons	List of button to unregister bindings on
#
# Results:
#	None
#
# Side Effects:
#	Destroy the toplevel widget created to represent the dragged
#	image iccon.
proc ::dragger::__destroydragger { w { buttons "" } } {
    variable DRAGGER
    variable log

    # Check that this is one of ours
    set idx [lsearch $DRAGGER(sources) $w]
    if { $idx < 0 } {
	${log}::warn "Drag source $w is not registered"
	return -code error "Unknown drag source $w"
    }

    set varname [namespace current]::$w
    upvar \#0 $varname dragsource

    # If no buttons were chosen, see to check all possible buttons for
    # that dragger.
    if { $buttons eq "" } { set buttons $dragsource(-buttons) }

    # Restore all original bindings for the drag source window.
    set bindsrc [expr {$dragsource(-indirector) eq "" \
			   ? $dragsource(win) : $dragsource(-indirector)}]
    foreach btn $buttons {
	bind $bindsrc <Motion> $dragsource(binding_Motion-$btn)
	if { [array names dragsource binding_ButtonRelease-$btn] ne "" } {
	    bind $bindsrc <ButtonRelease-$btn> \
		$dragsource(binding_ButtonRelease-$btn)
	}
    }

    # Destroy the top level that represented the image icon.
    destroy $dragsource(top)

    # Remove old bindings from context storage for the dragger, to be
    # clean and nice.
    foreach btn $buttons {
	unset dragsource(binding_Motion-$btn)
	if { [array names dragsource binding_ButtonRelease-$btn] ne "" } {
	    unset dragsource(binding_ButtonRelease-$btn)
	}
    }
}


# ::dragger::__release -- Dragged icon release callback
#
#	This procedure is bound so as to record whenever the dragged
#	image icon is released.  It call backs all the commands that
#	were associated to the -drop options and automatically
#	destroys the dragged image icon toplevel.
#
# Arguments:
#	w	Dragger that was the source of the movement
#	btn	Number of the button that was pressed to initiate the movement
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::dragger::__release { w btn } {
    variable DRAGGER
    variable log

    # Check that this is one of ours
    set idx [lsearch $DRAGGER(sources) $w]
    if { $idx < 0 } {
	${log}::warn "Drag source $w is not registered"
	return -code error "Unknown drag source $w"
    }

    set varname [namespace current]::$w
    upvar \#0 $varname dragsource

    # Callback all commands that are contained in the -drop list.
    foreach cmd $dragsource(-drop) {
	if { [catch {eval $cmd $w $btn [winfo pointerx $dragsource(top)] \
			 [winfo pointery $dragsource(top)]} res] } {
	    ${log}::warn "Error when invoking drop command $cmd: $res"
	}
    }

    # And remove the temporary top level that was created to represent
    # the image icon.
    __destroydragger $w [list $btn]
}


# ::dragger::__move -- Move image icon to position
#
#	This command is typically bound to motion events and shows the
#	dragged image icon to an absolute position on the screen.
#
# Arguments:
#	w	Identifier of the original dragger source.
#	px	X position (if none specified, current pointer will be used)
#	py	Y position (if none specified, current pointer will be used)
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::dragger::__move { w { px "" } { py "" } } {
    variable DRAGGER
    variable log

    # Check that this is one of ours
    set idx [lsearch $DRAGGER(sources) $w]
    if { $idx < 0 } {
	${log}::warn "Drag source $w is not registered"
	return -code error "Unknown drag source $w"
    }

    set varname [namespace current]::$w
    upvar \#0 $varname dragsource

    # Fetch current pointer location in absolute coordinates if
    # necessary (and in the context of the toplevel representing the
    # dragged image icon).
    if { $px eq "" } { set px [winfo pointerx $dragsource(top)] }
    if { $py eq "" } { set py [winfo pointery $dragsource(top)] }

    # Go set the position of the (shaped) top level, taking into
    # account the size of the image (and thus its size).
    set x [expr $px - round(0.5*[image width $dragsource(img)])]
    set y [expr $py - round(0.5*[image height $dragsource(img)])]
    wm geometry $dragsource(top) [join "+ $x + $y" {}]
}


# ::dragger::__start -- Start dragging an image
#
#	This procedure is typically bound to button press events on
#	the dragger source.  It creates a toplevel, possibly shaped,
#	that will follow the mouse pointer until the button is
#	released.  The procedure modifies the bindings of the dragger
#	source to that end (indeed, upon button press, a grab occurs
#	and motion events are sent to the source window).
#
# Arguments:
#	w	Identifier of the original dragger source
#	btn	Number of the button that is being pressed.
#
# Results:
#	None
#
# Side Effects:
#	Will create a temporary toplevel that will follow the mouse
#	pointer until button release.
proc ::dragger::__start { w btn } {
    variable DRAGGER
    variable log
    global tcl_platform

    # Check that this is one of ours
    set idx [lsearch $DRAGGER(sources) $w]
    if { $idx < 0 } {
	${log}::warn "Drag source $w is not registered"
	return -code error "Unknown drag source $w"
    }

    set varname [namespace current]::$w
    upvar \#0 $varname dragsource
    
    # Create a new toplevel if there is none yet.  We see to not
    # having any decorations around the toplevel.
    if { ! [winfo exists $dragsource(top)] } {
	${log}::info "Creating toplevel $dragsource(top)"
	toplevel $dragsource(top)
	wm overrideredirect $dragsource(top) on
	if { $tcl_platform(platform) eq "windows" \
		 && [string is true $DRAGGER(-topmost)] } {
	    wm attributes $dragsource(top) -topmost on
	}

	# If we can do window shaping, make the transparent pixels of
	# the image violet since this is required by the current
	# tktrans implementation.
	if { $DRAGGER(shapecapable) } {
	    ::imgop::opaque $dragsource(img) #FF00FF
	}
    }

    # Move the (new) top level to the current absolute position of the
    # pointer and force an update to really make sure the toplevel
    # exists before calling tktrans.
    __move $w \
	[winfo pointerx $dragsource(win)] [winfo pointery $dragsource(win)]
    update

    # Register the external window shape for the new toplevel via
    # tktrans if we are shape capable.
    if { $DRAGGER(shapecapable) } {
	[namespace current]::tktrans::settoplevel \
	    $dragsource(top) $dragsource(img)
    }


    # Now create a canvas within the new toplevel and see to put the
    # image into te canvas.  We really could use a label here.
    set cs $dragsource(top).c
    if { ! [winfo exists $cs] } {
	canvas $cs -highlightthickness 0 -border 0
	pack $cs
	$cs create image 0 0 -image $dragsource(img) -anchor nw -tags "icon"
    } else {
	# Update the canvas if it already existed (I don't think we
	# are ever going to trigger this code, but this is for
	# completeness).
	$cs itemconfigure icon -image $dragsource(img)
    }

    # Remember the current bindings that are associated to the source
    # dragger and start listening for motion and release events on
    # that window (since a grab occurs on button press, all events
    # will be routed there).
    set bindsrc [expr {$dragsource(-indirector) eq "" \
			   ? $dragsource(win) : $dragsource(-indirector)}]
    set dragsource(binding_Motion-${btn}) [bind $bindsrc <Motion>]
    set dragsource(binding_ButtonRelease-${btn}) \
	[bind $bindsrc <ButtonRelease-${btn}>]
    bind $bindsrc <Motion> +[list ::dragger::__move $w]
    bind $bindsrc <ButtonRelease-${btn}> +[list ::dragger::__release $w $btn]
}


# ::dragger::new -- Create a new dragger
#
#	This procedure register a new image to be associated to a
#	window and sees to create the appropriate bindings so that
#	button presses on that source window will create a floating
#	image icon that follows pointer motion until the button is
#	released.
#
# Arguments:
#	w	Identifier of dragger source
#	img	Tk image or path to file for the image icon.
#	args	Additional key values for options.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::dragger::new { w img args } {
    variable DRAGGER
    variable log

    set idx [lsearch $DRAGGER(sources) $w]
    if { $idx < 0 } {
	set varname [namespace current]::$w
	upvar \#0 $varname dragsource

	for { set top ".dragger$DRAGGER(idgene)" } \
	    { [winfo exist $top] } { incr DRAGGER(idgene) } {
		set top ".dragger$DRAGGER(idgene)"
	    }

	set dragsource(win) $w
	set dragimg "::dragger::image_[incr DRAGGER(idgene)]"
	set dragsource(img) [::imgop::duplicate $img $dragimg]
	set dragsource(top) $top
	lappend DRAGGER(sources) $w

	::uobj::inherit DRAGGER dragsource
    }

    eval config $w $args

    return $w
}


# ::dragger::__destroy -- Destroys a dragger
#
#	This procedure is called upon destruction of the dragger
#	source.  All context is removed and any existing dragged
#	window is destroyed.
#
# Arguments:
#	w	Identifier of the dragger source
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::dragger::__destroy { w } {
    variable DRAGGER
    variable log

    set idx [lsearch $DRAGGER(sources) $w]
    if { $idx >= 0 } {
	set varname [namespace current]::$w
	upvar \#0 $varname dragsource

	${log}::debug "Automatically removing dragger on $w"

	if { [winfo exists $dragsource(top)] } {
	    __destroydragger $w
	    destroy $dragsource(top)
	    image delete $dragsource(img)
	}
	
	unset dragsource
	set DRAGGER(sources) [lreplace $DRAGGER(sources) $idx $idx]
    }
}


# ::dragger::config -- (Re)configure a dragger
#
#	Change the options associated to a dragger or get these.
#
# Arguments:
#	w	Identifier of the dragger source.
#	args	List of key values when setting, one key or none when getting
#
# Results:
#	This procedure will either set or get the options associated
#	to a dragger.  When called with no arguments it returns a list
#	with all the options and their values.  When called with one
#	argument it returns the value of that option.  Otherwise, it
#	sets the options passed in the arguments together with their
#	values.
#
# Side Effects:
#	None.
proc ::dragger::config { w args } {
    variable DRAGGER
    variable log

    # Check that this is one of ours
    set idx [lsearch $DRAGGER(sources) $w]
    if { $idx < 0 } {
	${log}::warn "Drag source $w is not registered"
	return -code error "Unknown drag source $w"
    }

    set varname [namespace current]::$w
    upvar \#0 $varname dragsource

    set result [eval ::uobj::config dragsource "-*" $args]

    if { [winfo exists $w] } {
	foreach btn $dragsource(-buttons) {
	    ${log}::debug "Registering dragger $w for button $btn"
	    bind $w <ButtonPress-$btn> \
		+[list ::dragger::__start $w $btn]
	}
	bind $w <Destroy> +[list ::dragger::__destroy %W]
    }

    return $result
}

package provide dragger 0.1
