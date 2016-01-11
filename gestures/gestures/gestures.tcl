# gestures.tcl -- Simple mouse gestures
#
#	This module implements a simplistic mouse gesture recognition
#	module.  The idea is to sub-sample from each main point and
#	decide upon the direction that had been taken once the
#	sub-sampling pixel border has been crossed.  For now on, the
#	module does not support diagonals.  The module has no
#	dependency on Tk, it is up to the callers to push event
#	information into this module to trigger mouse gesture pattern
#	recognition callbacks.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.


package require Tcl 8.4

package require uobj


namespace eval ::gestures {
    variable GEST
    if { ! [info exists GEST] } {
	array set GEST {
	    idgene      0
	    -subsample  20
	    allowed     "UDLRsca"
	    current     ""
	}
	variable libdir [file dirname [file normalize [info script]]]
	::uobj::install_log [namespace current] GEST; # Creates 'log' variable
	::uobj::install_defaults [namespace current] GEST
    }
}

# The implementation is inspired by an article from the code
# project: http://www.codeproject.com/cpp/PoorMansMouseGesture.asp
#
# The idea is to start building a virtual square at the first click of
# a mouse gesture detection.  Once the mouse pointer passes one of the
# edges of the square, the edge passed decides if the mouvement was to
# the left, right, upwards or downwards.  Once the edge was passed, a
# new virtual square is constructed and the algorithm starts over
# again.  Mouvements are reduced to their upper most simplification so
# that whenever down down are detected, only down is kept.  Since the
# current implementation allows to pass the corners of the square, it
# introduces internally 4 new directions (1 7 9 and 3 (look on your
# numeric keypad!)).  Once a mouse gesture has ended, a deep search is
# executed so that all occurences of 1 are replaced by left down and
# down left, the whole sequence reduced as explained above and the
# result being tested against all registered gestures.
#
# Diagonals are important. Therefore, one extension to this algorithm
# would be to work with angles in a similar way.  As soon as the mouse
# pointer would be too far from the starting point, the angle between
# the horizontal and the resulting vector would be computed and the
# ownership to an octant would decide upon the direction taken (which
# gives us diagonals).


# ::gestures::config -- (re)configure a recognition context
#
#	This procedure reconfigure a recognition context.
#
# Arguments:
#	recog	Identifier of recognition context.
#	args	List of key val dash led options
#
# Results:
#	Return all options, the value of the option requested or set
#	the options passed as a parameter.
#
# Side Effects:
#	None.
proc ::gestures::config { recog args } {
    variable GEST
    variable log

    if { ! [info exists $recog] } {
	${log}::warn "Unknown gesture recogniser context $recog"
	return -code error "Unknown gesture recogniser context"
    }

    upvar \#0 $recog Recogniser

    return [eval ::uobj::config Recogniser "-*" $args]
}


# ::gestures::new -- New gesture context
#
#	This procedure creates a new gesture context, all further
#	functions needs the so-created context.
#
# Arguments:
#	args	List of key val dash led options
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::gestures::new { args } {
    variable GEST
    variable log

    set varname "::gestures::Recogniser_[incr GEST(idgene)]"
    upvar \#0 $varname Recogniser

    set Recogniser(id) $GEST(idgene)
    set Recogniser(current) ""    ;# Current mouse gesture being contructed
    set Recogniser(trail) [list]  ;# Trail of mouse mouvements
    set Recogniser(center) [list] ;# Last square recognition center

    # Copy options
    ::uobj::inherit GEST Recogniser
    
    # Do configuration
    eval config $varname $args

    return $varname
}


# ::gestures::__clean -- Clean a gesture description string
#
#	This procedure will clean a gesture description string by
#	avoiding the appearance of twice the same letter in pairs and
#	by removing unrecognised letters.
#
# Arguments:
#	gest	Incoming pattern
#
# Results:
#	Return a clean gesture pattern, where all doublets have been
#	removed
#
# Side Effects:
#	None.
proc ::gestures::__clean { gest } {
    variable GEST
    variable log

    set cleaned ""
    set prev ""
    set len [string length $gest]
    for {set i 0} {$i < $len} {incr i} {
	set char [string index $gest $i]
	if { $char ne $prev && [string first $char $GEST(allowed)] >= 0 } {
	    append cleaned $char
	}
	set prev $char
    }
    
    return $cleaned
}


# ::gestures::add -- Add a new gesture
#
#	This command register a new gesture that will be recognised
#	whenever it occurs.  The gesture description is a string where
#	the following characters have the following meaning: U, D, L
#	and R mean respectively Up, Down, Left and Right and s, c and
#	a stands for the state of the shift, control and alt keys.  If
#	the gesture already existed, the callback will be added to the
#	list of already registered callbacks for the gesture.
#
# Arguments:
#	gest	New gesture to install.
#	cb	Command to callback.
#
# Results:
#	Returns the cleaned gesture.
#
# Side Effects:
#	None.
proc ::gestures::add { recog gest cb } {
    variable GEST
    variable log

    set gest [__clean $gest]

    if { $gest ne "" } {
	if { ! [info exists $recog] } {
	    ${log}::warn "Unknown gesture recogniser context $recog"
	    return -code error "Unknown gesture recogniser context"
	}
	
	upvar \#0 $recog Recogniser

	set varname "::gestures::Gesture_$Recogniser(id)_${gest}"
	if { ! [info exists $varname] } {
	    upvar \#0 $varname Gesture
	    
	    set Gesture(recogniser) $Recogniser(id)
	    set Gesture(gesture) $gest
	    set Gesture(callbacks) [list $cb]
	} else {
	    upvar \#0 $varname Gesture
	    
	    lappend Gesture(callbacks) $cb
	}
    }
    
    return $gest
}


# ::gestures::delete -- Delete a mouse gesture context
#
#	This procedure deletes a mouse gesture context and all the
#	gestures that have been created within that context.
#
# Arguments:
#	recog	Identifier of recognition context.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::gestures::delete { recog } {
    variable GEST
    variable log

    if { ! [info exists $recog] } {
	${log}::warn "Unknown gesture recogniser context $recog"
	return -code error "Unknown gesture recogniser context"
    }

    upvar \#0 $recog Recogniser
    
    foreach varname [info vars "::gestures::Gesture_$Recogniser(id)_*"] {
	upvar \#0 $varname Gesture
	unset Gesture
    }
    unset Recogniser
}


# ::gestures::__recognise -- Performs gesture recognition
#
#	This procedure deep searches after all combinations of the
#	incoming gesture trail where diagonals (seldom found) are
#	replaced by their up, down, left and right equivalents (in all
#	orders).  Once all combinations have been found, these are
#	looked up amoug the recognition patterns that have been
#	registered and callbacks are deliver on match.
#
# Arguments:
#	recog	Recognition context
#	gest	Gesture trail (1,3,7 and 9 allowed)
#	cx	Center of trail
#	cy	Center of trail
#
# Results:
#	None
#
# Side Effects:
#	Deliver appropriate callbacks.
proc ::gestures::__recognise { recog gest cx cy } {
    variable GEST
    variable log
    
    upvar \#0 $recog Recogniser
    
    # Deep search all possibilities for replacing 1, 3, 5 and 9 by
    # their up, down, left and right equivalents.
    set i1 [string first "1" $gest]
    if { $i1 >= 0 } {
	__recognise $recog [string replace $gest $i1 $i1 "LD"] $cx $cy
	__recognise $recog [string replace $gest $i1 $i1 "DL"] $cx $cy
    }
    set i3 [string first "3" $gest]
    if { $i3 >= 0 } {
	__recognise $recog [string replace $gest $i3 $i3 "RD"] $cx $cy
	__recognise $recog [string replace $gest $i3 $i3 "DR"] $cx $cy
    }
    set i7 [string first "7" $gest]
    if { $i7 >= 0 } {
	__recognise $recog [string replace $gest $i7 $i7 "LU"] $cx $cy
	__recognise $recog [string replace $gest $i7 $i7 "UL"] $cx $cy
    }
    set i9 [string first "9" $gest]
    if { $i9 >= 0 } {
	__recognise $recog [string replace $gest $i9 $i9 "RU"] $cx $cy
	__recognise $recog [string replace $gest $i9 $i9 "UR"] $cx $cy
    }

    # We don't have any, we are somewhere at the bottom of the
    # recursion, trigger the matching gesture callbacks if any.
    if { $i1 < 0 && $i3 < 0 && $i7 < 0 && $i9 < 0 } {
	# Clean a last time to replace all doublets
	set gest [__clean $gest]

	# And match against registered patterns
	foreach varname [info vars "::gestures::Gesture_$Recogniser(id)_*"] {
	    upvar \#0 $varname Gesture
	    if { $Gesture(gesture) eq $gest } {
		foreach cb $Gesture(callbacks) {
		    if { [catch {eval $cb $recog $gest $cx $cy} res] } {
			${log}::warn \
			    "Error when invoking callback $cb: $res"
		    }
		}
	    }
	}
    }
}


# ::gestures::__appendonce -- Append char once to string
#
#	This procedure will append a character to a string only if it
#	is not alread present at the string end.
#
# Arguments:
#	varname	Name of variable holding the string
#	char	Character to append
#
# Results:
#	Return 1 if the character was appended, 0 otherwise
#
# Side Effects:
#	None.
proc ::gestures::__appendonce { varname char } {
    upvar $varname var
    if { [string index $var end] ne $char } {
	append var $char
	return 1
    }

    return 0
}


# ::gestures::__bbox -- Compute bounding box of points
#
#	This procedure computes the bounding box of a list of points.
#
# Arguments:
#	points	An even long list of x y coordinates of the points.
#
# Results:
#	Return a list with 4 items: minx, miny, maxx, maxy
#
# Side Effects:
#	None.
proc ::gestures::__bbox { points } {
    set minx 2147483647
    set maxx -2147483647
    set miny 2147483647
    set maxy -2147483647

    foreach {x y} $points {
	if { $x < $minx } { set minx $x }
	if { $x > $maxx } { set maxx $x }
	if { $y < $miny } { set miny $y }
	if { $y > $maxy } { set maxy $y }
    }

    return [list $minx $miny $maxx $maxy]
}


# ::gestures::push -- Push state into recognition context
#
#	This procedure is designed to be bound for a widget in which
#	recognition is necessary.  It pushes information into the
#	recognition context and will trigger appropriate callbacks
#	once patterns have been recognised.  The arguments depend on
#	the type of the event for which information is being pushed.
#	The recognised types are: KeyPress, KeyRelease (ignored),
#	ButtonPress, ButtonRelease and Motion.  Key events should be
#	followed by the keysym of the event.  Mouse button events
#	should be followed by the number of the button and the x and y
#	of the event position.  Motion events should be followed by
#	the x and y of the event.  The positions should be expressed
#	in the same coordinate system (use %X and %Y everywhere, or %x
#	%y on the same widget always).
#
# Arguments:
#	recog	Recognition context
#	type	Type of the event being pushed.
#	args	Arguments to the event, depending on its type.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::gestures::push { recog type args } {
    variable GEST
    variable log
    
    if { ! [info exists $recog] } {
	${log}::warn "Unknown gesture recogniser context $recog"
	return -code error "Unknown gesture recogniser context"
    }
    
    upvar \#0 $recog Recogniser

    switch -glob -- $type {
	"KeyPress*" {
	    set keysym [lindex $args 0]
	    if { [string match "*SHIFT*" [string toupper $keysym]] } {
		__appendonce Recogniser(current) "s"
	    }
	    if { [string match "*ALT*" [string toupper $keysym]] } {
		__appendonce Recogniser(current) "a"
	    }
	    if { [string match "*CONTROL*" [string toupper $keysym]] \
		     || [string match "*CTL*" [string toupper $keysym]]} {
		__appendonce Recogniser(current) "c"
	    }
	}
	"ButtonPress*" {
	    set x [lindex $args 0]
	    set y [lindex $args 1]
	    set Recogniser(trail) [list]
	    set Recogniser(center) [list $x $y]
	}
	"Motion*" {
	    set x [lindex $args 0]
	    set y [lindex $args 1]
	    lappend Recogniser(trail) $x $y
	    foreach {cx cy} $Recogniser(center) break
	    set dx [expr $x - $cx]
	    set dy [expr $y - $cy]

	    # Handle diagonally outside the center interaction
	    # sub-sampling square correctly, even though diagonals are
	    # not used in the final recognition.
	    if { $dx >= $Recogniser(-subsample) } {
		if { $dy >= $Recogniser(-subsample) } {
		    __appendonce Recogniser(current) "3"
		    set Recogniser(center) [list $x $y]
		    ${log}::debug "Recognising trail is $Recogniser(current)"
		} elseif { $dy <= [expr -$Recogniser(-subsample)] } {
		    __appendonce Recogniser(current) "9"
		    set Recogniser(center) [list $x $y]
		    ${log}::debug "Recognising trail is $Recogniser(current)"
		} else {
		    __appendonce Recogniser(current) "R"
		    set Recogniser(center) [list $x $y]
		    ${log}::debug "Recognising trail is $Recogniser(current)"
		}
	    }
	    if { $dx <= [expr -$Recogniser(-subsample)] } {
		if { $dy >= $Recogniser(-subsample) } {
		    __appendonce Recogniser(current) "1"
		    set Recogniser(center) [list $x $y]
		    ${log}::debug "Recognising trail is $Recogniser(current)"
		} elseif { $dy <= [expr -$Recogniser(-subsample)] } {
		    __appendonce Recogniser(current) "7"
		    set Recogniser(center) [list $x $y]
		    ${log}::debug "Recognising trail is $Recogniser(current)"
		} else {
		    __appendonce Recogniser(current) "L"
		    set Recogniser(center) [list $x $y]
		    ${log}::debug "Recognising trail is $Recogniser(current)"
		}
	    }
	    if { $dy >= $Recogniser(-subsample) } {
		if { $dx >= $Recogniser(-subsample) } {
		    __appendonce Recogniser(current) "3"
		    set Recogniser(center) [list $x $y]
		    ${log}::debug "Recognising trail is $Recogniser(current)"
		} elseif { $dx <= [expr -$Recogniser(-subsample)] } {
		    __appendonce Recogniser(current) "1"
		    set Recogniser(center) [list $x $y]
		    ${log}::debug "Recognising trail is $Recogniser(current)"
		} else {
		    __appendonce Recogniser(current) "D"
		    set Recogniser(center) [list $x $y]
		    ${log}::debug "Recognising trail is $Recogniser(current)"
		}
	    }
	    if { $dy <= [expr -$Recogniser(-subsample)] } {
		if { $dx >= $Recogniser(-subsample) } {
		    __appendonce Recogniser(current) "9"
		    set Recogniser(center) [list $x $y]
		    ${log}::debug "Recognising trail is $Recogniser(current)"
		} elseif { $dx <= [expr -$Recogniser(-subsample)] } {
		    __appendonce Recogniser(current) "7"
		    set Recogniser(center) [list $x $y]
		    ${log}::debug "Recognising trail is $Recogniser(current)"
		} else {
		    __appendonce Recogniser(current) "U"
		    set Recogniser(center) [list $x $y]
		    ${log}::debug "Recognising trail is $Recogniser(current)"
		}
	    }
	}
	"ButtonRelease*" {
	    # Compute center of trail
	    foreach {minx miny maxx maxy} [__bbox $Recogniser(trail)] break
	    set cx [expr int(0.5*($minx + $maxx))]
	    set cy [expr int(0.5*($miny + $maxy))]

	    # Trigger recognition, replacing diagonals by up, down,
	    # left and right combinations.
	    __recognise $recog $Recogniser(current) $cx $cy
	    set Recogniser(center) [list]
	    set Recogniser(current) ""
	}
    }
}


package provide gestures 0.1
