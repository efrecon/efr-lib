# zshader.tcl -- Slowly shades away Zinc items
#
#	This module will sees to slowly shade away items on a Zinc
#	canvas, shading is done by modifying the alpha value of the
#	necessary features of the items.  The module provides with a
#	simple event system to let external callers knowing about the
#	various decisions that the shader takes.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.4
package require Tk
package require Tkzinc

package require uobj

namespace eval ::zshader {
    variable ZSHADER
    if { ! [info exists ZSHADER] } {
	array set ZSHADER {
	    shaders          ""
	    -consider        "*"
	    -reject          ""
	    -time            2000
	    -period          75
	    -restoreondelete on
	    -autostart       on
	    idgene           0
	}
	variable libdir [file dirname [file normalize [info script]]]
	::uobj::install_log zshader ZSHADER; # Creates log namespace variable
	::uobj::install_defaults zshader ZSHADER; # Creates defaults procedure
    }
}


# ::zshader::__trigger -- Trigger necessary callbacks
#
#	This command relays actions that occur within a shader, into
#	external callers.  Basically, it calls back all matching
#	callbacks, which implements some sort of event model.
#
# Arguments:
#	shader	Identifier of the shader, as returned by ::zshader::new
#	action	Action that occurs (event!)
#	args	Further argument definition for the event.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::zshader::__trigger { shader action args } {
    variable ZSHADER
    variable log

    upvar \#0 $shader SHADER

    # Call all callbacks that have registered for matching actions.
    if { [array names SHADER callbacks] ne "" } {
	foreach {ptn cb} $SHADER(callbacks) {
	    if { [string match $ptn $action] } {
		if { [catch {eval $cb $shader $action $args} res] } {
		    ${log}::warn \
			"Error when invoking $action callback $cb: $res"
		}
	    }
	}
    }
}


# ::zshader::find -- Find a shader
#
#	This procedure looks for all matching shaders among those that
#	are known.
#
# Arguments:
#	cs	Zinc canvas, can be empty for selection on whichever canvas
#	grp	Name of group on canvas, can also be empty for selection of all
#
# Results:
#	Returns the list of shaders that matched the incoming canvas
#	and group specifications.  Since empty strings are allowed for
#	these, the procedure returns a list of matching items, not
#	always a single item.
#
# Side Effects:
#	None.
proc ::zshader::find { cs grp } {
    variable ZSHADER
    variable log

    set shaders [list]
    foreach s $ZSHADER(shaders) {
	upvar \#0 $s SHADER
	if { ($cs eq "" || ($cs ne "" && $SHADER(canvas) eq $cs)) \
		 && ($grp eq "" || ($grp ne "" && $SHADER(group) eq $grp)) } {
	    lappend shaders $s
	}
    }

    return $shaders
}


# ::zshader::__traverse -- Traverse and gather items
#
#	This procedure traverses the group that is associated to a
#	shader and computes the list of items that should be shaded.
#	Items that should be shaded are those which tags match one of
#	the patterns of the -consider option, except those which tags
#	match one of the patterns of the -reject option.
#
# Arguments:
#	shader	Identifier of shader
#
# Results:
#       Return the list of matching items in the tree below the group.
#
# Side Effects:
#	None.
proc ::zshader::__traverse { shader } {
    variable ZSHADER
    variable log

    upvar \#0 $shader SHADER
    ${log}::debug \
	"Traversing $shader <$SHADER(canvas),$SHADER(group)> for items"

    set items [list]

    # First resolve the group to its raw Zinc item numbers (which
    # would allow us to use pathtags for specifying the group if we
    # wished).
    foreach itm [$SHADER(canvas) find withtag $SHADER(group)] {
	# Then recursively get all the sub items of each group item
	foreach sub [$SHADER(canvas) find withtag .${itm}*] {
	    # And for each of these, get their tags so that we can
	    # match against the allowance/denial filter.
	    foreach tag [$SHADER(canvas) gettags $sub] {
		set allow 0
		foreach ptn $SHADER(-consider) {
		    if { [string match $ptn $tag] } {
			set allow 1
		    }
		}
		foreach ptn $SHADER(-reject) {
		    if { [string match $ptn $tag] } {
			set allow 0
		    }
		}
		if { $allow } {
		    lappend items $tag
		}
	    }
	}
    }

    return [lsort -unique $items]
}


# ::zshader::__shadeitem -- Shade an item
#
#	This procedure is the core animation routine.  Depending on
#	the action, it will shade or restore the item to its original
#	state.  When shading, the procedure performs a linear
#	interpolation on all colorable properties of the items, so
#	that its alpha value gradually fades to full transparency.
#
# Arguments:
#	shader	Identifier of a shader, as returned by ::zshader::new
#	action	Action to perform, can be "shade" or "restore"
#	item_a	Even list containing all information on the item (array set)
#	now	Current time (used for alpha value linear interpolation)
#	end	End time (used for alpha value linear interpolation)
#
# Results:
#	Return the (possibly modified) item array information in the
#	form of an even list ready for an array set command.  This
#	procedure supposes to be able to store information in this
#	even list for remembering information between calls.
#
# Side Effects:
#	None.
proc ::zshader::__shadeitem { shader action item_a { now 0 } { end -1 } } {
    variable ZSHADER
    variable log

    array set item $item_a
    if { [array names item start] eq "" } { set item(start) $now }
    if { $end < $now } { set end $now }
    ${log}::debug "Shading operation: $action on $item(tag) <$now,$end>"

    if { $action == "shade" } {
	__trigger $shader ItemShade $item(tag) [expr {$end - $now}]
    } else {
	__trigger $shader ItemRestore $item(tag)
    }

    # Ask the item what type it is and decide upon which features
    # (colors) we should try to shade.
    set colopts [list]
    switch [$item(canvas) type $item(tag)] {
	"rectangle" -
	"arc" {
	    set colopts [list -fillcolor -linecolor]
	}
	"icon" {
	    set colopts [list -color]
	}
	"curve" {
	    set colopts [list -fillcolor -linecolor -markercolor]
	}
    }
    
    # If we could reason (we do not support all item types (yet) and
    # some items do not have any appropriate features), do some linear
    # shadowing so that the item will be invisible at the end.  Catch
    # away errors to account for items that could have been removed
    # from the group.
    if { [llength $colopts] > 0 } {
	foreach opt $colopts {
	    if { [catch {$item(canvas) itemcget $item(tag) $opt} gradient]==0 \
		     && $gradient ne "" } {
		# XXX: We only support simple color gradients,
		# sorry...
		foreach {c a} [split $gradient ";"] break
		if { $a eq "" } { set a 100 }; # No alpha means fully opaque
		if { [array names item $opt] eq "" } {
		    set item($opt) $a
		}
		
		if { $action eq "shade" } {
		    if { $now >= $end } {
			set alpha 0
		    } else {
			set factor \
			    [expr {double($now-$item(start))/ \
				       ($end-$item(start))}]
			set alpha \
			    [expr {round($item($opt) - $item($opt)*$factor)}]
			if { $alpha > 100 } { set alpha 100 }
			if { $alpha < 0 } { set alpha 0 }
		    }
		} else {
		    set alpha $item($opt)
		}
		
		$item(canvas) itemconfigure $item(tag) $opt "${c};${alpha}"
	    }
	}
    }

    # Remove animation support from item when restoring back to
    # normal.
    if { $action eq "restore" } {
	unset item(start)
	foreach opt [array names item -*] {
	    unset item($opt)
	}
    }

    # Returned (modified) item
    return [array get item]
}


# ::zshader::__shade -- Shader animation loop
#
#	This procedure selects the sub items of a shader that should
#	be animated (shaded) and regularily schedules itself to
#	perform the shading animation if necessary.  The procedure
#	attempts to account for new items that could be added to the
#	original shader Zinc group under the time of an animation.
#	Typically, these items will be shaded quicker than those that
#	were present from the start.
#
# Arguments:
#	shader	Identifier of a shader, as returned by ::zshader::new
#
# Results:
#	Returns the list of items tags that are being shaded.
#
# Side Effects:
#	None.
proc ::zshader::__shade { shader } {
    variable ZSHADER
    variable log

    # Exit if this is none of our shaders
    set idx [lsearch $ZSHADER(shaders) $shader]
    if { $idx < 0 } {
	${log}::warn "$shader does not identify a valid zShader"
	return -code error "$shader does not identify a valid zShader"
    }

    upvar \#0 $shader SHADER

    # Take care of time issues.  Remember what time it is, and
    # initialises the shader to remember when we started and when we
    # should stop.
    set now [clock clicks -milliseconds]
    if { $SHADER(start) eq "" } {
	set SHADER(start) $now
    }
    set end [expr {$SHADER(start) + $SHADER(-time)}]

    # Traverse the group according to the traversal options at this
    # time and remember all new items that we have discovered since
    # the shader was last run.  This algorithm will not remove items
    # from the list of known items.
    set grpitems [__traverse $shader]
    foreach itm $grpitems {
	# Look in known items for one that has the same tag.
	set found 0
	foreach i $SHADER(items) {
	    array set olditem $i
	    if { $olditem(tag) eq $itm } {
		set found 1
		break
	    }
	}
	# If we had not any item with the same tag, then this one is
	# new and we initialise it and remember it.
	if { ! $found } {
	    set newitem(tag) $itm
	    set newitem(canvas) $SHADER(canvas)
	    lappend SHADER(items) [array get newitem]
	    __trigger $shader ItemNew $itm
	}
    }

    # Now we can start reasoning about how to shade all these items.
    # We will act through the alpha channel only.
    set newitems [list]
    foreach itm $SHADER(items) {
	lappend newitems [__shadeitem $shader shade $itm $now $end]
    }
    set SHADER(items) $newitems

    # Reschedule a new shading loop
    if { $now <= $end } {
	set SHADER(next) [after $SHADER(-period) ::zshader::__shade $shader]
    } else {
	set SHADER(next) ""
    }

    return $grpitems
}


# ::zshader::get -- Get shader properties
#
#	This procedure returns some semi-internal shader properties to
#	other modules.  The properties that are recognised are canvas
#	(the TkZinc name of the canvas), id the identifier of the
#	shader, start the time at which animation was last started
#	(can be empty), group the name of the top item being animated,
#	items the list of sub-items that have been considered for
#	animation so far, or any other option of the shader (all
#	starting with a dash (-)).
#
# Arguments:
#	shader	Identifier of shader as returned by ::zshader::new
#	type	Property to get
#
# Results:
#	The value of the property
#
# Side Effects:
#	None.
proc ::zshader::get { shader type } {
    variable ZSHADER
    variable log

    # Exit if this is none of our shaders
    set idx [lsearch $ZSHADER(shaders) $shader]
    if { $idx < 0 } {
	${log}::warn "$shader does not identify a valid zShader"
	return -code error "$shader does not identify a valid zShader"
    }

    upvar \#0 $shader SHADER

    switch -glob -- $type {
	"canvas" -
	"id" -
	"start" -
	"group" {
	    return $SHADER($type)
	}
	"items" {
	    set items [list]
	    foreach itm $SHADER(items) {
		array set $itm item
		lappend items $item(tag)
	    }
	    return $items
	}
	"-*" {
	    return [config $shader $type]
	}
    }

    return ""
}


# ::zshader::config -- Get/set shader options
#
#	This procedure get or set the options of a given shader.  The
#	options that are currently being recognised are the following.
#	-consider is a list of patterns whose sub items tags of the
#	group will have to match to be shaded.  -reject is a list of
#	patterns whose sub items of the group will have to match to
#	not be considered for shading.  -time is the time (in
#	milliseconds) of the shading animation.  -period is the
#	frequency of the animation, it should be much less than the
#	animation time.  -restoreondelete will restore the items to
#	their original shape on deletion.
#
# Arguments:
#	shader	Identifier of the shader, as returned by ::zshader::new.
#	args	List of key values when setting, one key or none when getting
#
# Results:
#	This procedure will either set or get the options associated
#	to a shader.  When called with no arguments it returns a list
#	with all the options and their values.  When called with one
#	argument it returns the value of that option.  Otherwise, it
#	sets the options passed in the arguments together with their
#	values.
#
# Side Effects:
#	None.
proc ::zshader::config { shader args } {
    variable ZSHADER
    variable log

    set idx [lsearch $ZSHADER(shaders) $shader]
    if { $idx < 0 } {
	${log}::warn "$shader does not identify a valid zShader"
	return -code error "$shader does not identify a valid zShader"
    }

    upvar \#0 $shader SHADER
    set result [eval ::uobj::config SHADER "-*" $args]
    

    if { [string is true $SHADER(-autostart)] } {
	if { $SHADER(next) ne "" } {
	    after cancel $SHADER(next)
	    set SHADER(next) ""
	}
	set SHADER(next) [after idle ::zshader::__shade $shader]
    }

    # XXX: When Zinc is able to register events on items other that
    # those that have to do with interaction, i.e. destroy events, we
    # should be able to automatically remove shaders when the top
    # group disappears.
    
    return $result
}


# ::zshader::new -- Create a new shader
#
#	This procedure creates a new shader taking the options into
#	account.  The shader is started automatically.
#
# Arguments:
#	cs	Zinc canvas on which to operate
#	grp	Name of group under which all items will be shaded
#	args	List of dash led options to control the shading (see config)
#
# Results:
#	Return an identifier for the shader, this identifier can be
#	used for further operations on the shader.
#
# Side Effects:
#	None.
proc ::zshader::new { cs grp args } {
    variable ZSHADER
    variable log

    set shader [find $cs $grp]
    if { $shader eq "" } {
	set shader [namespace current]::shader_[incr ZSHADER(idgene)]
	upvar \#0 $shader SHADER
	
	set SHADER(canvas) $cs
	set SHADER(group) $grp
	set SHADER(id) $shader
	set SHADER(start) ""
	set SHADER(items) [list]
	set SHADER(next) ""
	set SHADER(callbacks) [list]
	lappend ZSHADER(shaders) $shader

	::uobj::inherit ZSHADER SHADER
    }

    eval config $shader $args

    return $shader
}


# ::zshader::restore -- Restore a shader
#
#	This procedure will instantly stop shading animation, if
#	necessary, and restore all shaded items to their original
#	appearance, if possible.
#
# Arguments:
#	shader	Identifier of the shader, as returned by ::zshader::new.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::zshader::restore { shader } {
    variable ZSHADER
    variable log

    set idx [lsearch $ZSHADER(shaders) $shader]
    if { $idx < 0 } {
	${log}::warn "$shader does not identify a valid zShader"
	return -code error "$shader does not identify a valid zShader"
    }

    upvar \#0 $shader SHADER
    if { $SHADER(next) ne "" } {
	after cancel $SHADER(next)
	set SHADER(next) ""
    }
    
    set newitems [list]
    foreach itm $SHADER(items) {
	lappend newitems [__shadeitem $shader restore $itm]
    }
    set SHADER(items) $newitems
    set SHADER(start) ""
}


# ::zshader::delete -- Delete a shader
#
#	This procedure will instantly delete a shader, restoring all
#	its items to their original appearance if requested so.
#
# Arguments:
#	shader	Identifier of the shader, as returned by ::zshader::new.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::zshader::delete { shader } {
    variable ZSHADER
    variable log

    set idx [lsearch $ZSHADER(shaders) $shader]
    if { $idx < 0 } {
	${log}::warn "$shader does not identify a valid zShader"
	return -code error "$shader does not identify a valid zShader"
    }

    upvar \#0 $shader SHADER
    if { [string is true $SHADER(-restoreondelete)] } {
	restore $shader
    }
    unset SHADER
    set ZSHADER(shaders) [lreplace $ZSHADERS(shaders) $idx $idx]
}


# ::zshader::monitor -- Event monitoring system
#
#	This command will arrange for a callback every time an event
#	which name matches the pattern passed as a parameter occurs
#	within a shader.  The callback will be called with the identifier
#	of the shader, followed by the name of the event and
#	followed by a number of additional arguments which are event
#	dependent.
#
# Arguments:
#	shader	Identifier of the shader, as returned by ::zshader::new
#	ptn	String match pattern for event name
#	cb	Command to callback every time a matching event occurs.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::zshader::monitor { shader ptn cb } {
    variable ZSHADER
    variable log

    set idx [lsearch $ZSHADER(shaders) $shader]
    if { $idx < 0 } {
	${log}::warn "$shader does not identify a valid zShader"
	return -code error "$shader does not identify a valid zShader"
    }
    upvar \#0 $shader SHADER

    lappend SHADER(callbacks) $ptn $cb
}


package provide zshader 0.1
