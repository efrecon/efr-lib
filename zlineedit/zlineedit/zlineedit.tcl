# zlineedit.tcl -- Interactive poly-line editor for Zinc
#
#	This module provides facilities for the interactive edition of
#	poly-lines on a Zinc canvas.  The module provides facilities
#	for both the creation of polylines and for the amending of
#	created polylines.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.4
package require Tk
package require Tkzinc

package require uobj

namespace eval ::zlineedit {
    variable ZLE
    if { ! [info exists ZLE] } {
	array set ZLE {
	    -lineeditstyle   "-filled off -linecolor red -relief flat"
	    -linestyle       "-filled off -linecolor blue -relief flat"
	    -markerstyle     "-filled on -fillcolor orange -linecolor black -relief flat"
	    -markereditstyle "-filled on -fillcolor red -linecolor black -relief flat"
	    -markersize      9
	    -parent          1
	    -interaction     "VERTEXMOVE VERTEXREMOVE VERTEXADD LINEMOVE"
	    -autostart       on
	    -roottag         ""
	    -outlinestyle    ""
	    idgene           0
	    dbgcb            0
	}
	variable libdir [file dirname [file normalize [info script]]]
	::uobj::install_log zlineedit ZLE; # Creates log namespace variable
	::uobj::install_defaults zlineedit ZLE; # Creates defaults procedure
    }
}


# Implemenations Notes:
#
# There are two types that this modules handles internally: editors
# and vertices.  All editors are created via the ::new command and
# their variable will start with 'editor_' followed by an
# automatically generated identifier.  This will uniquely identify the
# editor, including for the callers.  Vertices are named similarily,
# beginning with the keyword 'vertex_'.  Vertices are either created
# from the ::new command or interactively.  The coordinates of the
# vertices of the polyline is always uniquely contained in the vertex
# objects, which allows for the reordering of the vertices within a
# line.
#
# This module tries to centralise activities to a single point and
# context in the form of (sometimes lengthy) procedures.  This
# provides what I felt was more readable code, by avoiding spreading
# the event reactions to numerous inter-twined procedures.  Some of
# these procedures store "private" data in the type that they are
# handling by prefixing this data with their name (and this name will
# start with two underscore since these are local procedures).


# ::zlineedit::find -- Find an editor by one of its tags
#
#	This procedure looks among the existing line editors if there
#	is any one which line matches a given tag.  This routine can
#	be used to find "lost" editors.
#
# Arguments:
#	zcs	Zinc canvas
#	tag	Tag of the line of the editor to find
#
# Results:
#	Returns the identifier of the line editor, or an empty string.
#
# Side Effects:
#	None.
proc ::zlineedit::find { zcs tag } {
    variable ZLE
    variable log

    foreach v [info vars [namespace current]::editor_*] {
	upvar #0 $v EDITOR
	if { $EDITOR(root) ne "" && [$zcs hastag $EDITOR(root) $tag] } {
	    return $v
	}
    }
    return ""
}

# ::zlineedit::__trigger -- Trigger necessary callbacks
#
#	This command relays actions that occur within an editor, into
#	external callers.  Basically, it calls back all matching
#	callbacks, which implements some sort of event model.
#
# Arguments:
#	editor	Identifier of the editor, as returned by ::zlineedit::new
#	action	Action that occurs (event!)
#	args	Further argument definition for the event.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::zlineedit::__trigger { editor action args } {
    variable ZLE
    variable log

    upvar \#0 $editor EDITOR

    # Call all callbacks that have registered for matching actions.
    if { [array names EDITOR callbacks] ne "" } {
	foreach {ptn cb} $EDITOR(callbacks) {
	    if { [string match $ptn $action] } {
		if { [catch {eval $cb $editor $action $args} res] } {
		    ${log}::warn \
			"Error when invoking $action callback $cb: $res"
		}
	    }
	}
    }
}


# ::zlineedit::__vertexedit -- Interaction for vertex edition.
#
#	This procedure is a self-contained implementation that handles
#	the interactive positioning of vertices on the canvas.  The
#	procedure takes uses an internal action to call itself and
#	register the appropriate bindings.  It is initialise by the
#	"BIND" action.
#
# Arguments:
#	vertex	Identifier of the vertex
#	action	Action to perform: BIND, UNBIND, START, STOP, MOTION, REMOVE
#	x	X position of mouse in canvas coordinates
#	y	Y position of mouse in canvas coordinates
#
# Results:
#	None.
#
# Side Effects:
#	Will change the shape of the line
proc ::zlineedit::__vertexedit { vertex action { x "" } { y "" }} {
    variable ZLE
    variable log

    upvar #0 $vertex VERTEX
    upvar #0 $VERTEX(editor) EDITOR
    if { $ZLE(dbgcb) } {
	${log}::debug \
	    "Vertex edition callback on $vertex: $action - <${x},${y}>"
    }

    # Initialise localvariables in the vertex array
    foreach { k v } [list boundmove 0 boundremove 0 boundfocus 0 motion ""] {
	if { [array names VERTEX __vertexedit_$k] eq "" } {
	    set VERTEX(__vertexedit_$k) $v
	}
    }
    
    # Now perform actions depending on the operation requested in the
    # incoming procedure arguments.
    switch $action {
	"BIND" {
	    # Initialise the whole interactive session through
	    # registering this procedure to be called on various sorts
	    # of button press and release.  This is done in accordance
	    # with the type of interaction allowed for the line
	    # editor.
	    if { [lsearch $EDITOR(-interaction) "VERTEXMOVE"] >= 0 } {
		if { ! $VERTEX(__vertexedit_boundmove) } {
		    $EDITOR(canvas) bind $VERTEX(itm) <ButtonPress-1> \
			"::zlineedit::__vertexedit $vertex START %x %y"
		    $EDITOR(canvas) bind $VERTEX(itm) <ButtonRelease-1> \
			"::zlineedit::__vertexedit $vertex STOP %x %y"
		    set VERTEX(__vertexedit_boundmove) 1
		}
	    } elseif { $VERTEX(__vertexedit_boundmove) } {
		$EDITOR(canvas) bind $VERTEX(itm) <ButtonPress-1> {}
		$EDITOR(canvas) bind $VERTEX(itm) <ButtonRelease-1> {}
		set VERTEX(__vertexedit_boundmove) 0
		# Restore global motion binding on whole canvas if we
		# were moving where the unbinding was requested.
		if { [array names VERTEX __vertexedit_x] ne "" } {
		    bind $EDITOR(canvas) <Motion> $VERTEX(__vertexedit_motion)
		}
	    }
	    if { [lsearch $EDITOR(-interaction) "VERTEXREMOVE"] >= 0 } {
		if { ! $VERTEX(__vertexedit_boundremove) } {
		    $EDITOR(canvas) bind $VERTEX(itm) <ButtonRelease-3> \
			"::zlineedit::__vertexedit $vertex REMOVE"
		    $EDITOR(canvas) bind $VERTEX(itm) <Double-1> \
			"::zlineedit::__vertexedit $vertex REMOVE"
		    set VERTEX(__vertexedit_boundremove) 1
		}
	    } elseif { $VERTEX(__vertexedit_boundremove) } {
		$EDITOR(canvas) bind $VERTEX(itm) <ButtonRelease-3> {}
		$EDITOR(canvas) bind $VERTEX(itm) <Double-1> {}
		set VERTEX(__vertexedit_boundremove) 0
	    }
	    if { [lsearch $EDITOR(-interaction) "VERTEXMOVE"] >= 0 \
		     || [lsearch $EDITOR(-interaction) "VERTEXREMOVE"] >= 0 } {
		if { ! $VERTEX(__vertexedit_boundfocus) } {
		    $EDITOR(canvas) bind $VERTEX(itm) <Enter> \
			"::zlineedit::__vertexedit $vertex ENTER"
		    $EDITOR(canvas) bind $VERTEX(itm) <Leave> \
			"::zlineedit::__vertexedit $vertex LEAVE"
		    set VERTEX(__vertexedit_boundfocus) 1
		}
	    } else {
		$EDITOR(canvas) bind $VERTEX(itm) <Enter> {}
		$EDITOR(canvas) bind $VERTEX(itm) <Leave> {}
		set VERTEX(__vertexedit_boundfocus) 0
	    }
	}
	"UNBIND" {
	    # Diable the whole interactive session through
	    # unregistering the bindings that were established during
	    # the BIND operation.
	    if { $VERTEX(__vertexedit_boundmove) } {
		$EDITOR(canvas) bind $VERTEX(itm) <ButtonPress-1> {}
		$EDITOR(canvas) bind $VERTEX(itm) <ButtonRelease-1> {}
		set VERTEX(__vertexedit_boundmove) 0
		# Restore global motion binding on whole canvas if we
		# were moving where the unbinding was requested.
		if { [array names VERTEX __vertexedit_x] ne "" } {
		    bind $EDITOR(canvas) <Motion> $VERTEX(__vertexedit_motion)
		}
	    }
	    if { $VERTEX(__vertexedit_boundremove) } {
		$EDITOR(canvas) bind $VERTEX(itm) <ButtonRelease-3> {}
		$EDITOR(canvas) bind $VERTEX(itm) <Double-1> {}
		set VERTEX(__vertexedit_boundremove) 0
	    }
	    if { $VERTEX(__vertexedit_boundfocus) } {
		$EDITOR(canvas) bind $VERTEX(itm) <Enter> {}
		$EDITOR(canvas) bind $VERTEX(itm) <Leave> {}
		set VERTEX(__vertexedit_boundfocus) 0
	    }
	}
	"ENTER" {
	    if { [string is false $VERTEX(lock)] } {
		set VERTEX(editing) on
		__draw $EDITOR(self)
	    }
	}
	"LEAVE" {
	    set VERTEX(editing) off
	    __draw $EDITOR(self)
	}
	"START" {
	    # Button was pressed, register a mouse motion binding that
	    # will interactively move the vertex with the mouse
	    # cursor.
	    if { [string is false $VERTEX(lock)] } {
		$EDITOR(canvas) raise $VERTEX(itm)
		set VERTEX(__vertexedit_motion) [bind $EDITOR(canvas) <Motion>]
		set VERTEX(__vertexedit_x) $x
		set VERTEX(__vertexedit_y) $y
		bind $EDITOR(canvas) <Motion> \
		    "::zlineedit::__vertexedit $vertex MOTION %x %y"
	    }
	}
	"MOTION" {
	    # When in motion, interactively move the vertex to where
	    # the mouse pointer is on the canvas.  We only work in
	    # offsets here, absolute positioning on the canvas would
	    # let the vertices jump to a given location when simply
	    # clicking on the vertices.
	    set dx [expr {$x - $VERTEX(__vertexedit_x)}]
	    set dy [expr {$y - $VERTEX(__vertexedit_y)}]
	    set VERTEX(x) [expr {$VERTEX(x) + $dx}]
	    set VERTEX(y) [expr {$VERTEX(y) + $dy}]
	    set VERTEX(__vertexedit_x) $x
	    set VERTEX(__vertexedit_y) $y
	    __draw $EDITOR(self)
	}
	"STOP" {
	    if { [string is false $VERTEX(lock)] \
		     && [array names VERTEX __vertexedit_x] ne "" } {
		# Button was released, restore the motion bindings to
		# what they were and leave the vertex where it is.
		bind $EDITOR(canvas) <Motion> $VERTEX(__vertexedit_motion)
		# Remove temporary variables that we used for offset
		# computation.  This cleanup is important since we use
		# their presence for detecting if we are moving a
		# point when an unbind operation is issued.
		unset VERTEX(__vertexedit_x)
		unset VERTEX(__vertexedit_y)
		__trigger $EDITOR(self) VertexMove $vertex $VERTEX(x) $VERTEX(y)
	    }
	}
	"REMOVE" {
	    # Remove the vertex from the line editor.
	    if { [string is false $VERTEX(lock)] } {
		removevertex $vertex
	    }
	}
    }
}

# ::zlineedit::__lineedit -- Interaction for line edition.
#
#	This procedure is a self-contained implementation that handles
#	the interactive positioning of lines on the canvas and the
#	addition of vertices to these lines.  The procedure takes uses
#	an internal action to call itself and register the appropriate
#	bindings.  It is initialise by the "BIND" action.
#
# Arguments:
#	editor	Identifier of the line editor
#	action	Action to perform: BIND, UNBIND, START, STOP, MOTION, ADD
#	x	X position of mouse in canvas coordinates
#	y	Y position of mouse in canvas coordinates
#
# Results:
#	None.
#
# Side Effects:
#	Will change the shape of the line
proc ::zlineedit::__lineedit { editor action { x "" } { y "" }} {
    variable ZLE
    variable log

    upvar #0 $editor EDITOR
    if { $ZLE(dbgcb) } {
	${log}::debug "Line edition callback on $editor: $action - <${x},${y}>"
    }

    # Initialise localvariables in the editor array
    foreach { k v } [list boundmove 0 boundadd 0 boundfocus 0 motion ""] {
	if { [array names EDITOR __lineedit_$k] eq "" } {
	    set EDITOR(__lineedit_$k) $v
	}
    }

    set lines [list $EDITOR(line)]
    if { $EDITOR(outline) ne "" } { lappend lines $EDITOR(outline) }
    
    # Now perform actions depending on the operation requested in the
    # incoming procedure arguments.
    switch $action {
	"BIND" {
	    # Initialise the whole interactive session through
	    # registering this procedure to be called on various sorts
	    # of button press and release.  This is done in accordance
	    # with the type of interaction allowed for the line
	    # editor.
	    if { [lsearch $EDITOR(-interaction) "LINEMOVE"] >= 0 } {
		if { ! $EDITOR(__lineedit_boundmove) } {
		    foreach itm $lines {
			$EDITOR(canvas) bind $itm <ButtonPress-1> \
			    "::zlineedit::__lineedit $editor START %x %y"
			$EDITOR(canvas) bind $itm <ButtonRelease-1> \
			    "::zlineedit::__lineedit $editor STOP %x %y"
		    }
		    set EDITOR(__lineedit_boundmove) 1
		}
	    } elseif { $EDITOR(__lineedit_boundmove) } {
		foreach itm $lines {
		    $EDITOR(canvas) bind $itm <ButtonPress-1> {}
		    $EDITOR(canvas) bind $itm <ButtonRelease-1> {}
		}
		set EDITOR(__lineedit_boundmove) 0
		# Restore global motion binding on whole canvas if we
		# were moving where the unbinding was requested.
		if { [array names EDITOR __lineedit_x] ne "" } {
		    bind $EDITOR(canvas) <Motion> $EDITOR(__lineedit_motion)
		}
	    }
	    if { [lsearch $EDITOR(-interaction) "VERTEXADD"] >= 0 } {
		if { ! $EDITOR(__lineedit_boundadd) } {
		    foreach itm $lines {
			$EDITOR(canvas) bind $itm <ButtonRelease-3> \
			    "::zlineedit::__lineedit $editor ADD %x %y"
			$EDITOR(canvas) bind $itm <Double-1> \
			    "::zlineedit::__lineedit $editor ADD %x %y"
		    }
		    set EDITOR(__lineedit_boundadd) 1
		}
	    } elseif { $EDITOR(__lineedit_boundadd) } {
		foreach itm $lines {
		    $EDITOR(canvas) bind $itm <ButtonRelease-3> {}
		    $EDITOR(canvas) bind $itm <Double-1> {}
		}
		set EDITOR(__lineedit_boundadd) 0
	    }
	    if { [lsearch $EDITOR(-interaction) "LINEMOVE"] >= 0 \
		     || [lsearch $EDITOR(-interaction) "VERTEXADD"] >= 0 } {
		if { ! $EDITOR(__lineedit_boundfocus) } {
		    foreach itm $lines {
			$EDITOR(canvas) bind $itm <Enter> \
			    "::zlineedit::__lineedit $editor ENTER %x %y"
			$EDITOR(canvas) bind $itm <Leave> \
			    "::zlineedit::__lineedit $editor LEAVE %x %y"
		    }
		    set EDITOR(__lineedit_boundfocus) 1
		}
	    } elseif { $EDITOR(__lineedit_boundfocus) } {
		foreach itm $lines {
		    $EDITOR(canvas) bind $itm <Enter> {}
		    $EDITOR(canvas) bind $itm <Leave> {}
		}
		set EDITOR(__lineedit_boundfocus) 0
	    }
	}
	"UNBIND" {
	    # Disable the whole interactive session through
	    # unregistering the bindings that were established during
	    # the BIND operation.
	    if { $EDITOR(__lineedit_boundmove) } {
		foreach itm $lines {
		    $EDITOR(canvas) bind $itm <ButtonPress-1> {}
		    $EDITOR(canvas) bind $itm <ButtonRelease-1> {}
		}
		set EDITOR(__lineedit_boundmove) 0
		# Restore global motion binding on whole canvas if we
		# were moving where the unbinding was requested.
		if { [array names EDITOR __lineedit_x] ne "" } {
		    bind $EDITOR(canvas) <Motion> $EDITOR(__lineedit_motion)
		}
	    }
	    if { $EDITOR(__lineedit_boundadd) } {
		foreach itm $lines {
		    $EDITOR(canvas) bind $itm <ButtonRelease-3> {}
		    $EDITOR(canvas) bind $itm <Double-1> {}
		}
		set EDITOR(__lineedit_boundadd) 0
	    }
	    if { $EDITOR(__lineedit_boundfocus) } {
		foreach itm $lines {
		    $EDITOR(canvas) bind $itm <Enter> {}
		    $EDITOR(canvas) bind $itm <Leave> {}
		}
		set EDITOR(__lineedit_boundfocus) 0
	    }
	}
	"ENTER" {
	    set EDITOR(editing) on
	    __draw $editor
	}
	"LEAVE" {
	    set EDITOR(editing) off
	    __draw $editor
	}
	"START" {
	    # Button was pressed, register a mouse motion binding that
	    # will interactively move the line with the mouse
	    # cursor.
	    $EDITOR(canvas) raise $EDITOR(root)
	    set EDITOR(__lineedit_motion) [bind $EDITOR(canvas) <Motion>]
	    set EDITOR(__lineedit_x) $x
	    set EDITOR(__lineedit_y) $y
	    bind $EDITOR(canvas) <Motion> \
		"::zlineedit::__lineedit $editor MOTION %x %y"
	}
	"MOTION" {
	    # When in motion, interactively move the editor to where
	    # the mouse pointer is on the canvas.  We only work in
	    # offsets here, absolute positioning on the canvas would
	    # let the vertices jump to a given location when simply
	    # clicking on the vertices.
	    set dx [expr {$x - $EDITOR(__lineedit_x)}]
	    set dy [expr {$y - $EDITOR(__lineedit_y)}]
	    foreach vertex $EDITOR(vertices) {
		upvar #0 $vertex VERTEX
		if { [string is false $VERTEX(lock)] } {
		    set VERTEX(x) [expr {$VERTEX(x) + $dx}]
		    set VERTEX(y) [expr {$VERTEX(y) + $dy}]
		}
	    }
	    set EDITOR(__lineedit_x) $x
	    set EDITOR(__lineedit_y) $y
	    __draw $EDITOR(self)
	}
	"STOP" {
	    if { [array names EDITOR __lineedit_x] ne "" } {
		# Button was released, restore the motion bindings to
		# what they were and leave the line where it is.
		bind $EDITOR(canvas) <Motion> $EDITOR(__lineedit_motion)
		# Remove temporary variables that we used for offset
		# computation.  This cleanup is important since we use
		# their presence for detecting if we are moving a
		# point when an unbind operation is issued.
		unset EDITOR(__lineedit_x)
		unset EDITOR(__lineedit_y)
		__trigger $editor LineMove
	    }
	}
	"ADD" {
	    if { $EDITOR(outline) eq "" } {
		set line $EDITOR(line)
	    } else {
		set line $EDITOR(outline)
	    }
	    foreach {contour vertex edgevertex} \
		[$EDITOR(canvas) vertexat $line $x $y] break
	    ${log}::debug \
		"Picked vertices from $EDITOR(self): $vertex $edgevertex"
	    if { $vertex > $edgevertex } {
		insertvertex $editor $x $y $vertex on
	    } else {
		insertvertex $editor $x $y $edgevertex on
	    }		
	}
    }
}


# ::zlineedit::__linecreate -- Interaction for line creation.
#
#	This procedure is a self-contained implementation that handles
#	the interactive creation of lines on the canvas and the
#	addition of vertices to these lines.  The procedure uses an
#	internal action to call itself and register the appropriate
#	bindings.  It is initialise by the "BIND" action.
#
# Arguments:
#	editor	Identifier of the line editor
#	actions	Action to perform in sequence: BIND, UNBIND, MOTION, ADD, EMD
#	x	X position of mouse in canvas coordinates
#	y	Y position of mouse in canvas coordinates
#
# Results:
#	None.
#
# Side Effects:
#	Will add vertices to the line
proc ::zlineedit::__linecreate { editor actions { x "" } { y "" }} {
    variable ZLE
    variable log

    upvar #0 $editor EDITOR
    if { $ZLE(dbgcb) } {
	${log}::debug \
	    "Line creation callback on $editor: $actions - <${x},${y}>"
    }

    # Initialise localvariables in the editor array
    foreach { k v } [list bound 0 motion "" release1 "" release3 "" \
			 double ""] {
	if { [array names EDITOR __linecreate_$k] eq "" } {
	    set EDITOR(__linecreate_$k) $v
	}
    }

    # Initialise the binding action summary list, triplets with
    # information on where to store an existing binding (initialised
    # above), the binding, and finally, the action that this binding
    # will trigger.
    set bindings {
	motion <Motion> MOTION
	release1 <ButtonRelease-1> ADD
	release3 <ButtonRelease-3> {ADD END}
	double <Double-1> END
    }

    # Now perform actions depending on the operation requested in the
    # incoming procedure arguments.
    foreach action $actions {
	switch $action {
	    "BIND" {
		# Initialise the whole interactive session through
		# registering this procedure to be called on various sorts
		# of button press and release.
		if { ! $EDITOR(__linecreate_bound) } {
		    foreach { store binding operation } $bindings {
			set EDITOR(__linecreate_$store) \
			    [bind $EDITOR(canvas) $binding]
			bind $EDITOR(canvas) $binding \
			    +[list ::zlineedit::__linecreate $editor \
				  $operation %x %y]
		    }
		    set EDITOR(__linecreate_bound) 1
		    if { $x eq "" || $y eq "" } {
			foreach {x y} [winfo pointerxy $EDITOR(canvas)] break
			set x [expr $x - [winfo rootx $EDITOR(canvas)]]
			set y [expr $y - [winfo rooty $EDITOR(canvas)]]
		    }
		    # Simulate the first motion event so as to create
		    # the elastic band that will show that the line is
		    # in edition mode.
		    __linecreate $editor MOTION $x $y
		}
	    }
	    "UNBIND" {
		# Disable the whole interactive session through
		# unregistering the bindings that were established during
		# the BIND operation.
		if { $EDITOR(__linecreate_bound) } {
		    foreach { store binding operation } $bindings {
			bind $EDITOR(canvas) $binding \
			    $EDITOR(__linecreate_$store)
		    }
		    set EDITOR(__linecreate_bound) 0
		}
	    }
	    "MOTION" {
		if { [llength $EDITOR(vertices)] > 0 } {
		    if { $EDITOR(elastic) eq "" } {
			set EDITOR(elastic) \
			    [$EDITOR(canvas) add curve $EDITOR(root) \
				 [list 0 0] \
				 -tags $EDITOR(self)_elastic]
		    }
		    eval $EDITOR(canvas) itemconfigure $EDITOR(elastic) \
			$EDITOR(-linestyle)
		    set vertex [lindex $EDITOR(vertices) end]
		    upvar #0 $vertex VERTEX
		    $EDITOR(canvas) coords $EDITOR(elastic) \
			[list $VERTEX(x) $VERTEX(y) $x $y]
		}
	    }
	    "ADD" {
		# Add operation will add a vertex at the current x,y
		# position on the canvas.
		$EDITOR(canvas) remove $EDITOR(elastic)
		set EDITOR(elastic) ""
		set vertex [lindex $EDITOR(vertices) end]
		insertvertex $editor $x $y end on
	    }
	    "END" {
		# End will turn off the adding feature of the line editor,
		# which will allow users to further edit the new line
		# later on.
		$EDITOR(canvas) remove $EDITOR(elastic)
		set EDITOR(elastic) ""
		# Mark the editor as "finished with line creation" and be
		# sure to redraw the line editor, which will ensure that
		# we unbound this very series of bindings.  If we do not
		# redraw, we would end up with yet another vertex.
		set EDITOR(adding) off
		set EDITOR(editing) off
		__draw $editor
	    }
	}
    }
}

# ::zlineedit::__binding -- Force bindings on/off
#
#	This procedure will establish or remove the necessary bindings
#	on the various elements that form a line editor (the
#	representation of the vertices, etc.).  The procedure takes
#	its decision based on the current interactive state of the
#	line, i.e. if it is in the mode where clicks on the canvas
#	will automatically add vertices to it or not.
#
# Arguments:
#	editor	Identifier of the editor, as returned by ::zlineedit::new
#	bind	Should we bind or unbind
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::zlineedit::__binding { editor bind } {
    variable ZLE
    variable log
    
    upvar #0 $editor EDITOR

    if { [string is true $bind] } {
	# When in adding mode, we will be following the mouse motion
	# events to draw a skeleton line for the "next" line segment in
	# the process of creating a line, which means that we will not
	# want to bind any other events on the line editor representation
	# itself.  Decide this here.
	if { [string is true $EDITOR(adding)] } {
	    __lineedit $editor UNBIND
	    __linecreate $editor BIND
	    foreach vertex $EDITOR(vertices) {
		__vertexedit $vertex UNBIND
	    }
	} else {
	    foreach vertex $EDITOR(vertices) {
		__vertexedit $vertex BIND
	    }
	    if { [llength $EDITOR(vertices)] > 1 } {
		__lineedit $editor BIND
		__linecreate $editor UNBIND
	    }
	}
    } else {
	__lineedit $editor UNBIND
	foreach vertex $EDITOR(vertices) {
	    __vertexedit $vertex UNBIND
	    upvar #0 $vertex VERTEX
	    unset VERTEX
	}
	__linecreate $editor UNBIND
    }
}


# ::zlineedit::__tag -- Tag all line editor features
#
#	This command will see to tag all the currently present
#	features of a line editor with appropriate tags, i.e. using
#	the currently stated root tag.
#
# Arguments:
#	editor	Identifier of the editor, as returned by ::zlineedit::new
#
# Results:
#	Return the list of tags that were applied to the various items.
#
# Side Effects:
#	None.
proc ::zlineedit::__tag { editor } {
    variable ZLE
    variable log

    # Decide upon root tag to use for all items.
    upvar #0 $editor EDITOR
    if { $EDITOR(-roottag) eq "" } {
	set root $EDITOR(self);  # Already contains the unique EDITOR(id)
    } else {
	set root [string trim $EDITOR(-roottag)]_editor$EDITOR(id)
    }

    set tags [list]

    # Name root group for all sub-items of the line editor
    if { $EDITOR(root) ne "" \
	     && [$EDITOR(canvas) find withtag $root] eq "" } {
	$EDITOR(canvas) addtag $root withtag $EDITOR(root)
	lappend tags $root
    }

    # Name the polyline and outline, if any.
    foreach itm [list line outline] {
	if { $EDITOR($itm) ne "" \
		 && [$EDITOR(canvas) find withtag ${root}_${itm}] eq "" } {
	    $EDITOR(canvas) addtag ${root}_${itm} withtag $EDITOR($itm)
	    lappend tags ${root}_${itm}
	}
    }

    # Give a name to each vertex in turn, if any.
    foreach vertex $EDITOR(vertices) {
	upvar #0 $vertex VERTEX
	if { $VERTEX(itm) ne "" \
		 && [$EDITOR(canvas) find withtag \
			 ${root}_vertex$VERTEX(id)] eq "" } {
	    $EDITOR(canvas) addtag ${root}_vertex$VERTEX(id) \
		withtag $VERTEX(itm)
	    lappend tags ${root}_vertex$VERTEX(id)
	}
    }
    
    ${log}::debug \
	"Tagged [llength $tags] features of line editor $EDITOR(self)" 

    return $tags
}



# ::zlineedit::__draw -- Draw a line editor
#
#	This command draws a line editor, creating/removing all the
#	necessary graphical objects if necessary, and updating these
#	if they already existed.
#
# Arguments:
#	editor	Identifier of the editor, as returned by ::zlineedit::new
#
# Results:
#	None.
#
# Side Effects:
#	Will modify the canvas!
proc ::zlineedit::__draw { editor } {
    variable ZLE
    variable log

    upvar #0 $editor EDITOR

    # Create a group for enclosing all items that are related to the
    # line editor.
    if { $EDITOR(root) eq "" } {
	set EDITOR(root) [$EDITOR(canvas) add group $EDITOR(-parent)]
    }
    
    # We use the number of vertices in many places, cache it.
    set len [llength $EDITOR(vertices)]

    # If we have at least two vertices, the line editor should draw a
    # line.
    if { $len > 1 } {
	# Create the Zinc curve that will represent the line of the
	# editor.
	if { $EDITOR(line) eq "" } {
	    set EDITOR(line) [$EDITOR(canvas) add curve $EDITOR(root) \
				  [list 0 0]]
	}
	# Make sure that it is a child of the main group (this can
	# happen when we have taken over a polyline.
	if { [$EDITOR(canvas) group $EDITOR(line)] ne $EDITOR(root) } {
	    ${log}::info "Spontaneously pushed line $EDITOR(line) into\
                          editor group $EDITOR(root)"
	    $EDITOR(canvas) chggroup $EDITOR(line) $EDITOR(root) on
	}
	# Account for its appearance, as from the configuration of the
	# editor.
	if { [string is true $EDITOR(editing)] } {
	    eval $EDITOR(canvas) itemconfigure $EDITOR(line) \
		$EDITOR(-lineeditstyle)
	} else {
	    eval $EDITOR(canvas) itemconfigure $EDITOR(line) \
		$EDITOR(-linestyle)
	}
	
	if { $EDITOR(-outlinestyle) ne "" } {
	    # Create the Zinc curve that will represent the outline of
	    # the editor, put it under the line
	    if { $EDITOR(outline) eq "" } {
		set EDITOR(outline) [$EDITOR(canvas) add curve $EDITOR(root) \
					 [list 0 0]]
	    }
	    $EDITOR(canvas) lower $EDITOR(outline) $EDITOR(line)

	    # Account for its appearance, as from the configuration of
	    # the editor.
	    eval $EDITOR(canvas) itemconfigure $EDITOR(outline) \
		$EDITOR(-outlinestyle)

	    # Fix line width if none was specified, be sure to be
	    # larger than the line
	    if { [lsearch -glob $EDITOR(-outlinestyle) "-linew*"] < 0 } {
		set linewidth 1
		foreach cfginfo [$EDITOR(canvas) itemconfigure $EDITOR(line)] {
		    foreach {attr type ro unused val} $cfginfo {}
		    if { [string match "-linew*" $attr] } {
			set linewidth $val
		    }
		}
		set linewidth [expr {$linewidth + 2}]
		$EDITOR(canvas) itemconfigure $EDITOR(outline) \
		    -linewidth $linewidth
	    }
	}

	# Gather all the coordinates of the vertices and modify the
	# associated Zinc curve.
	set vlist [list]
	foreach vertex $EDITOR(vertices) {
	    upvar #0 $vertex VERTEX
	    lappend vlist $VERTEX(x) $VERTEX(y)
	}
	$EDITOR(canvas) coords $EDITOR(line) $vlist
	if { $EDITOR(outline) ne "" } {
	    $EDITOR(canvas) coords $EDITOR(outline) $vlist
	}
    } else {
	# Remove the Zinc curve if we have less than 2 vertices.
	if { [$EDITOR(canvas) find withtag $EDITOR(line)] ne "" } {
	    $EDITOR(canvas) remove $EDITOR(line)
	    set EDITOR(line) ""
	}
	if { $EDITOR(outline) ne "" \
		 && [$EDITOR(canvas) find withtag $EDITOR(outline)] ne "" } {
	    $EDITOR(canvas) remove $EDITOR(outline)
	    set EDITOR(outline) ""
	}
    }

    # If we have at least one vertex, represent each of these, in
    # turn, by a small rectangle.
    if { $len > 0 } {
	foreach vertex $EDITOR(vertices) {
	    upvar #0 $vertex VERTEX
	    # If we don't have any representation on the Zinc canvas,
	    # create an initial rectangle.
	    if { $VERTEX(itm) eq "" \
		     || [$EDITOR(canvas) find withtag $VERTEX(itm)] eq "" } {
		set VERTEX(itm) [$EDITOR(canvas) add rectangle $EDITOR(root) \
				     [list 0 0 0 0]]
	    }
	    # Account for its appearance, as from the configuration of the
	    # editor.
	    if { [string is true $VERTEX(editing)] } {
		eval $EDITOR(canvas) itemconfigure $VERTEX(itm) \
		    $EDITOR(-markereditstyle)
	    } else {
		eval $EDITOR(canvas) itemconfigure $VERTEX(itm) \
		    $EDITOR(-markerstyle)
	    }
	    $EDITOR(canvas) coords $VERTEX(itm) \
		[list \
		     [expr {$VERTEX(x) - round(0.5*$EDITOR(-markersize))}] \
		     [expr {$VERTEX(y) - round(0.5*$EDITOR(-markersize))}] \
		     [expr {$VERTEX(x) + round(0.5*$EDITOR(-markersize))}] \
		     [expr {$VERTEX(y) + round(0.5*$EDITOR(-markersize))}]]
	}
    }

    # Fix the bindings for the various parts of the line editor
    __binding $editor on
}


# ::zlineedit::vertexlock -- Set/Unset/Get Vertex lock
#
#	This procedure will lock or unlock a given vertex for edition
#	(movement) or get its current status.
#
# Arguments:
#	vertex	Identifier of the vertex
#	lock	New lock state of the vertex, empty to get info
#
# Results:
#	This procedure will return the current lock state of a vertex,
#	possibly after having changed it.
#
# Side Effects:
#	None.
proc ::zlineedit::vertexlock { vertex { lock "" }} {
    variable ZLE
    variable log

    upvar #0 $vertex VERTEX
    if { $lock ne "" } {
	${log}::info "Setting vertex lock state to $lock"
	set VERTEX(lock) $lock
    }
    return $VERTEX(lock)
}


# ::zlineedit::movevertex -- Change vertex position
#
#	This procedure will move a given vertex in an absolute or
#	relative way.  The vertex will be move even if it is locked.
#
# Arguments:
#	vertex	Identifier of the vertex
#	x	New x position or x displacement
#	y	New y position or y displacement
#	abs	Absolute displacement (otherwise relative to current position)
#
# Results:
#	This procedure will return the current position of the vertex,
#	as a list of two coordinates.
#
# Side Effects:
#	None.
proc ::zlineedit::movevertex { vertex x y {abs on}} {
    variable ZLE
    variable log

    upvar #0 $vertex VERTEX
    if { [string is true $abs] } {
	set VERTEX(x) $x
	set VERTEX(y) $y
    } else {
	set VERTEX(x) [expr {$VERTEX(x) + $x}]
	set VERTEX(y) [expr {$VERTEX(y) + $y}]
    }
    __draw $VERTEX(editor)
    
    return [list $VERTEX(x) $VERTEX(y)]
}


# ::zlineedit::removevertex -- Remove a vertex
#
#	Remove a vertex from its line editor.  Note that this does not
#	redraw the line editor on the canvas.
#
# Arguments:
#	vertex	Identifier of the vertex
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::zlineedit::removevertex { vertex } {
    variable ZLE
    variable log

    upvar #0 $vertex VERTEX
    upvar #0 $VERTEX(editor) EDITOR

    set idx [lsearch $EDITOR(vertices) $vertex]
    # If the vertex really was contained in the editor, unregister its
    # bindings, remove its representation from the Zinc canvas and
    # remove it from the list of vertices that are contained in the
    # editor.
    if { $idx >= 0 } {
	${log}::info "Removing vertex $vertex at $idx from $VERTEX(editor)"
	__vertexedit $vertex UNBIND
	$EDITOR(canvas) remove $VERTEX(itm)
	set EDITOR(vertices) [lreplace $EDITOR(vertices) $idx $idx]
	__trigger $EDITOR(self) VertexRemove $vertex $VERTEX(x) $VERTEX(y)
	unset VERTEX
	__draw $EDITOR(self)
    }
}


# ::modname::insertvertex -- Insert a vertex
#
#	This procedure inserts a vertex to the list of vertices of a
#	line editor.  By default, the vertex is appended to the list
#	of already existing vertices, but inserting within the list is
#	also possible.
#
# Arguments:
#	editor	Identifier of the editor
#	x	X position of the new vertex on the canvas
#	y	Y position of the new vertex on the canvas
#	where	Index for insertion in the list of editor's vertices.
#	redraw	Should we redraw after insertion?
#
# Results:
#	Return the identifier of the new vertex.
#
# Side Effects:
#	None.
proc ::zlineedit::insertvertex { editor x y { where end } { redraw off } } {
    variable ZLE
    variable log

    upvar #0 $editor EDITOR
    
    set id [incr ZLE(idgene)]
    set vertex [namespace current]::vertex_$id

    upvar #0 $vertex VERTEX
    set VERTEX(id) $id
    set VERTEX(x) $x
    set VERTEX(y) $y
    set VERTEX(editor) $editor
    set VERTEX(editing) off
    set VERTEX(lock) off
    set VERTEX(itm) ""
    
    set EDITOR(vertices) [linsert $EDITOR(vertices) $where $vertex]
    ${log}::info "Inserted vertex $vertex at $where in $editor"
    __trigger $EDITOR(self) VertexInsert $vertex $VERTEX(x) $VERTEX(y) $where

    if { [string is true $redraw] } {
	__draw $editor
	__tag $editor 
    }

    return $vertex
}


# ::zlineedit::adding -- Toggle/get interaction mode
#
#	This procedure either sends back the interaction mode or
#	changes it to the requested value.  A line editor is in
#	interaction mode when it tracks the motion of the pointer to
#	interactively add vertices to its end.
#
# Arguments:
#	editor	Identifier of the editor
#	adding	If not empty, new boolean value for the interaction mode
#
# Results:
#	Return the current interaction mode
#
# Side Effects:
#	None.
proc ::zlineedit::adding { editor { adding "" } } {
    variable ZLE
    variable log

    if { ! [info exists $editor] } {
	${log}::warn "$editor does not identify a valid line editor"
	return -code error "$editor does not identify a valid line editor"
    }
    upvar #0 $editor EDITOR

    if { $adding ne "" && [string is boolean $adding] } {
	${log}::info \
	    "Line editor $editor facility for appending vertices is: $adding"
	set EDITOR(adding) $adding
	config $editor
    }

    return $EDITOR(adding)
}


# ::zlineedit::move -- Move a line editor
#
#	This procedure will move all the vertices of a line editor by
#	a given offset. The movement is always relative to the current
#	position since the line has several vertices.
#
# Arguments:
#	editor	Identifier of line editor as returned by ::zlineedit::new
#	dx	Offset along x
#	dy	Offset along y
#
# Results:
#	None.
#
# Side Effects:
#	Move the line
proc ::zlineedit::move { editor {dx 0} {dy 0} } {
    variable ZLE
    variable log

    if { ! [info exists $editor] } {
	${log}::warn "$editor does not identify a valid line editor"
	return -code error "$editor does not identify a valid line editor"
    }
    upvar #0 $editor EDITOR

    foreach vertex $EDITOR(vertices) {
	upvar #0 $vertex VERTEX
	set VERTEX(x) [expr {$VERTEX(x) + $dx}]
	set VERTEX(y) [expr {$VERTEX(y) + $dy}]
    }
    __draw $editor
}


# ::zlineedit::get -- Get line editor properties
#
#	This procedure returns some semi-internal line editor
#	properties to other modules.  The properties that are
#	recognised are 'canvas' (the TkZinc name of the canvas), 'id'
#	the identifier of the shader, 'vertices' the list of vertices
#	identifier of the editor (can be empty), 'coords' the (even)
#	list of coordinates of the currently existing vertices, or any
#	other option of the shader (all starting with a dash (-)).
#
# Arguments:
#	editor	Identifier of line editor as returned by ::zlineedit::new
#	type	Property to get
#
# Results:
#	The value of the property
#
# Side Effects:
#	None.
proc ::zlineedit::get { editor type } {
    variable ZLE
    variable log

    if { ! [info exists $editor] } {
	${log}::warn "$editor does not identify a valid line editor"
	return -code error "$editor does not identify a valid line editor"
    }
    upvar #0 $editor EDITOR

    switch -glob -- $type {
	"canvas" -
	"id" -
	"root" -
	"vertices" {
	    return $EDITOR($type)
	}
	"coords" {
	    set coords [list]
	    foreach vertex $EDITOR(vertices) {
		upvar #0 $vertex VERTEX
		lappend coords $VERTEX(x) $VERTEX(y)
	    }
	    return $coords
	}
	"-*" {
	    return [config $editor $type]
	}
    }

    return ""
}


# ::zlineedit::config -- get/set line editor options
#
#	This procedure get or set the options of a given line editor.
#	The options that are currently being recognised are the
#	following.  -linestyle is a list of key and values that will
#	be apply to the line representation of the editor, and thus
#	can control its appearance.  -markerstyle is a similar list
#	for controlling the appearance of the vertex markers.
#	-lineeditstyle and -markereditstyle match the two previous
#	list and will be used for drawing during edition of the line
#	or the markers.  -markersize is the size in pixels of the
#	rectangular markers for the vertices.  -parent is the group
#	under which the line editor should be created.  -interaction
#	is a list of interactive operations that are allowed to
#	performed with the mouse on the line editor, these are
#	VERTEXMOVE, VERTEXREMOVE, VERTEXADD, LINEMOVE.
#
# Arguments:
#	shader	Identifier of the editor, as returned by ::zlineedit::new.
#	args	List of key values when setting, one key or none when getting
#
# Results:
#	This procedure will either set or get the options associated
#	to an editor.  When called with no arguments it returns a list
#	with all the options and their values.  When called with one
#	argument it returns the value of that option.  Otherwise, it
#	sets the options passed in the arguments together with their
#	values.
#
# Side Effects:
#	None.
proc ::zlineedit::config { editor args } {
    variable ZLE
    variable log

    if { ! [info exists $editor] } {
	${log}::warn "$editor does not identify a valid line editor"
	return -code error "$editor does not identify a valid line editor"
    }
    upvar #0 $editor EDITOR
    set result [eval ::uobj::config EDITOR "-*" $args]
    if { [string is false $EDITOR(-autostart)] } {
	set EDITOR(adding) off
    }
    if { [string is true $EDITOR(adding)] } {
	set EDITOR(editing) on
    }
    __draw $editor
    __tag $editor
    
    return $result
}


# ::zlineedit::__create -- Instantiate a new editor
#
#	This procedure creates a new editor.
#
# Arguments:
#	arg1	descr1
#	arg2	descr2
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::zlineedit::__create { zcs coords } {
    variable ZLE
    variable log

    set id [incr ZLE(idgene)]
    set editor [namespace current]::editor_$id
    upvar #0 $editor EDITOR
    
    set EDITOR(id) $id;         # Internal unique integer identifier
    set EDITOR(self) $editor;   # Identifier to the outside world (and internal)
    set EDITOR(editing) off;    # Editing the line or not (appearance control)?
    set EDITOR(adding) on;      # Default mode is interactive line creation
    set EDITOR(canvas) $zcs;    # Canvas on which the editor was created
    set EDITOR(root) "";        # Root Zinc group for all editor representation
    set EDITOR(line) "";        # Zinc line representation id
    set EDITOR(outline) "";     # Zinc outline representation id
    set EDITOR(elastic) "";     # Zinc elastic band representation id
    set EDITOR(vertices) [list]
    set EDITOR(callbacks) [list]
    set len [llength $coords]
    # Be smart about the coords argument of the argument list when
    # it is an even list: Initialise the line editor to contain
    # that many vertices
    if { $len > 0 && [expr {2*($len/2)}] == $len } {
	${log}::debug \
	    "Creating new line editor with [expr $len/2] initial vertices"
	foreach {x y} $coords {
	    if { $x ne "" && $y ne "" \
		     && [string is double $x] && [string is double $y] } {
		insertvertex $editor $x $y end off
	    } else {
		${log}::warn \
		    "Could not recognise <${x},${y}> as a valid vertex"
	    }
	}
	# Switch off interactive line creation when the line
	# editor is created with many vertices.
	if { $len > 2 } {
	    set EDITOR(adding) off
	}
    }
    
    # Inherit default options
    ::uobj::inherit ZLE EDITOR

    return $editor
}


# ::zlineedit::new -- Create a new editor
#
#	This procedure creates a new editor, taking the options given
#	as arguments into account.  When the first item of the
#	argument list is the tag of an existing editor, this procedure
#	behaves exactly as config.  When the first item is a list of
#	coordinates, the editor will be initialised to these
#	coordinates.  When there is only one point, the editor will
#	let the user interactively continuing with polyline edition in
#	an interactive way.  When the arguments are only options, the
#	editor will behave as above, letting the user interactively
#	create the fist vertex on the canvas on the next click as
#	well.
#
# Arguments:
#	zcs	Zinc canvas
#	args    List of dash led options to control the shading (see
#	        config), possibly preceeded by a list of coordinates
#
# Results:
#	Return an identifier for the line editor, this identifier can
#	be used for further operations on the shader.
#
# Side Effects:
#	Will register bindings for the creation and modification of a
#	polyline.
proc ::zlineedit::new { zcs args } {
    variable ZLE
    variable log

    # Try understanding the first argument, which could be an option,
    # a tag or a list of points.
    set first [lindex $args 0]
    if { [string index $first 0] != "-" } {
	set args [lrange $args 1 end]
    } else {
	set first ""
    }

    # If we had a first argument, try understanding it as an existing
    # tag on the canvas.  Jump into it if it already corresponds to an
    # editor, otherwise try to understand the tag as a curve if
    # possible.
    set editor ""
    set forced_drawstyle [list]
    if { $first ne "" } {
	if { [catch {$zcs find withtag $first} t] == 0 && $t ne "" } {
	    set editor [find $zcs $first]
	    if { $editor eq "" } {
		if { [$zcs type $first] eq "curve" } {
		    # We only use the first contour of the curve,
		    # which is a crude simplification.  However, that
		    # should serve most examples since this ability
		    # exists so as to be able to re-jump into an old
		    # edited curve for which we have lost the editor.
		    set editor [__create $zcs [join [$zcs coords $first]]]
		    # Fetch the drawing style of the incoming curve so
		    # as to be able to override the one stored in the
		    # line editor later down.
		    foreach cfginfo [$zcs itemconfigure $first] {
			foreach {attr type ro unused val} $cfginfo {}
			if { ! $ro && $attr ne "-tags" } {
			    lappend forced_drawstyle $attr $val
			}
		    }
		    # Push the style of the existing line into the
		    # editor context.
		    upvar #0 $editor EDITOR
		    set EDITOR(-linestyle) $forced_drawstyle
		    # Be sure to use this line as the editor line.
		    set EDITOR(line) [$zcs find withtag $first]
		} else {
		    ${log}::warn "$first is not a curve cannot understand it"
		    return -code error \
			"$first is not a curve cannot understand it"
		}
	    }
	}
    }

    # Create a new editor, taking into accounts a possible list of
    # initial points
    if { $editor eq "" } {
	set editor [__create $zcs $first]
    }

    # Configure editor with incoming arguments (remaining, since we possibly
    # have cut leading non-option arguments)
    eval config $editor $args

    # Return identifier for the line editor.
    return $editor
}


# ::zlineedit::delete -- Delete a line editor
#
#	This procedure will delete a line editor, possibly detaching
#	its polyline.
#
# Arguments:
#	editor	Interactive line editor
#	detach	Should we detach the created line (and not remove it!)
#
# Results:
#	Return the identifier of the detached polyline, if appropriate.
#
# Side Effects:
#	Once deleted, any reference to this line editor will fail.
proc ::zlineedit::delete { editor { detach off } } {
    variable ZLE
    variable log

    if { ! [info exists $editor] } {
	${log}::warn "$editor does not identify a valid line editor"
	return -code error "$editor does not identify a valid line editor"
    }
    upvar #0 $editor EDITOR

    ${log}::info "Deleting line editor $editor"

    set retval ""
    if { [string is true $detach] } {
	# Display it one last time, in normal mode.
	set EDITOR(editing) off
	__draw $editor
	# Move away the line from the group that contained the whole
	# editor, since we are soon going to be removing the group and
	# all its children.
	$EDITOR(canvas) chggroup $EDITOR(line) $EDITOR(-parent) on
	${log}::debug "Kept resulting polyline $EDITOR(line)"
	set retval $EDITOR(line)
    }
    # Force away bindings.
    __binding $editor off
    __trigger $editor Delete $detach
    $EDITOR(canvas) remove $EDITOR(root)
    unset EDITOR

    return $retval
}


# ::zlineedit::monitor -- Event monitoring system
#
#	This command will arrange for a callback every time an event
#	which name matches the pattern passed as a parameter occurs
#	within an editor.  The callback will be called with the identifier
#	of the editor, followed by the name of the event and
#	followed by a number of additional arguments which are event
#	dependent.
#
# Arguments:
#	editor	Identifier of the editor, as returned by ::zlineedit::new
#	ptn	String match pattern for event name
#	cb	Command to callback every time a matching event occurs.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::zlineedit::monitor { editor ptn cb } {
    variable ZLE
    variable log

    if { ! [info exists $editor] } {
	${log}::warn "$editor does not identify a valid line editor"
	return -code error "$editor does not identify a valid line editor"
    }
    upvar #0 $editor EDITOR

    lappend EDITOR(callbacks) $ptn $cb
}


package provide zlineedit 0.1
