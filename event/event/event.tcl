##################
## Module Name     --  event
## Original Author --  Emmanuel Frécon - emmanuel.frecon@myjoice.com
## Description:
##
##    This module provides for user-level event binding and
##    generation, in ways that are pretty similar to the way Tk event
##    system functions.  Events are associated to an "object", which
##    really is just a tag (even though the module contains some tiny
##    intellingence around object names that would originate from a
##    namespace).  Events are simply strings to which callers can
##    subscribe.  Subscription are done using string patterns, rather
##    than with the string identifying the event, so as to allow the
##    catching of a number of events within a single command.
##
##    There are two different types of event that the module is able
##    to trigger further.  The first type uses arguments that are
##    passed to the bound command just after the object and the event
##    itself.  The second type is able to replace strings such as %e
##    or the like to the arguments of the event at the time of calling
##    in the command.  For the seconds type, the arguments %e and %o
##    will always be replaced by, respectively the event (string) and
##    the object.
##
## Commands Exported:
##      ::event::bind
##      ::event::clean
##      ::event::trigger
##      ::event::generate
##      ::event::bindings
##      ::event::objects
##################

package require Tcl 8.4

package require logger
package require uobj

namespace eval ::event {
    variable EVENT
    if { ![info exists EVENT] } {
	array set EVENT {
	}
	variable libdir [file dirname [file normalize [info script]]]
	::uobj::install_log event EVENT
    }
}



# ::event::__tobindings -- Convert object identifier to internal storage varname
#
#       This procedure will take the name of an "object" as input and
#       output the name of a variable, hosted within this namespace,
#       that will be used in all further call to access binding data
#       for that object.  The only intelligence when it comes to the
#       object is around namespaces and :: strings, which are silently
#       replaced with __ to avoid namespace conflicts and
#       proliferation.
#
# Arguments:
#       obj	Identifier of an object
#
# Results:
#       Returns the fully qualified name of an internal variable for
#       storing information for that object.
#
# Side Effects:
#       None.
proc ::event::__tobindings { obj } {
    if { [string index $obj 0] ne ":" } {
	set obj "::$obj"
    }
    return [namespace current]::bindings_[string map [list ":" "_"] $obj]
}



# ::event::bind -- Bind a command to an event pattern on an object.
#
#       This procedure adds a binding for an event pattern on an
#       object.  Later, when event are generated and triggered, all
#       commands that match the object and the pattern bound in this
#       procedure will be called.  The module guarantees that events
#       will be called in the order that they have been bound to a
#       given object.
#
# Arguments:
#       obj	Identifier of an object
#       ptn	Event pattern that will be matched later
#       cmd	Command to invoke, will depend on the event type.
#
# Results:
#       Return the current number of bindings for the object.
#
# Side Effects:
#       None.
proc ::event::bind { obj ptn cmd } {
    variable log

    set bindings [__tobindings $obj]
    upvar \#0 $bindings BINDINGS
    if { ! [info exists $bindings] } {
	set BINDINGS(object) $obj;     # Object target for the binding
	set BINDINGS(bindings) [list]; # Initial bindings.
    }
    lappend BINDINGS(bindings) $ptn $cmd
    ${log}::info "Added \"$cmd\" binding for events matching $ptn on $obj"

    return [expr {[llength $BINDINGS(bindings)] / 2}]
}



# ::event::clean -- Clean away event bindings
#
#       This procedure cleans away event bindings for a given object.
#       All event which registration pattern and command match the
#       arguments will be removed.
#
# Arguments:
#       obj	Identifier of an object.
#       ptn	Pattern to match against the binding PATTERNS
#       cmdptn	Pattern to match against the binding COMMANDS
#
# Results:
#       Return the number of bindings that were removed.
#
# Side Effects:
#       None.
proc ::event::clean { obj { ptn * } { cmdptn * } } {
    variable log

    set bindings [__tobindings $obj]
    upvar \#0 $bindings BINDINGS
    
    ${log}::info "Cleaning event callbacks matching $ptn on $obj"
    set removed 0
    if { [info exists $bindings] } {
	set newbindings [list]
	foreach { cptn cmd } $BINDINGS(bindings) {
	    if { [string match $ptn $cptn] && [string match $cmdptn $cmd] } {
		${log}::debug "Removed event callback registered for\
                               <${cptn},${cmd}>"
		incr removed
	    } else {
		lappend newbindings $cptn $cmd
	    }
	}
	set BINDINGS(bindings) $newbindings
	if { [llength $BINDINGS(bindings)] == 0 } {
	    ${log}::debug "All bindings for $obj clean, removing internal state"
	    unset $bindings
	}
    }

    return $removed
}



# ::event::bindings -- Return current bindings for an object
#
#       This procedure returns the current bindings that exist for a
#       given object.  All the bindings which registration pattern
#       match the pattern passed as argument will be returned.  YES,
#       we match patterns on patterns!
#
# Arguments:
#       obj	Identifier of the object
#       ptn	Pattern to match against the binding PATTERNS
#
# Results:
#       Return the bindings that match, this is a list of pairs where
#       the first item is the registration pattern and the second the
#       command.
#
# Side Effects:
#       None.
proc ::event::bindings { obj { ptn * } } {
    variable log

    set bindings [__tobindings $obj]
    upvar \#0 $bindings BINDINGS
    
    ${log}::info "Listing event bindings matching $ptn on $obj"
    set existing [list]
    if { [info exists $bindings] } {
	foreach { cptn cmd } $BINDINGS(bindings) {
	    if { [string match $ptn $cptn] } {
		lappend existing $cptn $cmd
	    }
	}
    }

    return $existing
}



# ::event::objects -- Return currently known objects
#
#       This procedure will return the list of objects that currently
#       have bindings and which name match the pattern passed as a
#       parameter.
#
# Arguments:
#       ptn	Object identifier pattern.
#
# Results:
#       Return the list of objects that match and are known to this
#       module, i.e. have bindings.
#
# Side Effects:
#       None.
proc ::event::objects { { ptn * } } {
    variable log

    set objs [list]
    foreach bindings [info vars [namespace current]::bindings_*] {
	upvar \#0 $bindings BINDINGS

	if { [string match $ptn $BINDINGS(object)] } {
	    lappend objs $BINDINGS(object)
	}
    }

    return $objs
}



# ::event::trigger -- Trigger an event, first type of event.
#
#       This procedure forms the core of the event triggering for
#       events of the first type.  It considers that events are just a
#       list of arguments, arguments that will be passed further to
#       the command that was bound to the object just after the
#       identifier of the object and the name of the event.
#
# Arguments:
#       obj	Identifier of the object on which the event occurs.
#       evt	Name of the event that occurs
#       args	Further arguments to the event passed blindly to the command
#
# Results:
#       Return the number of commands that were triggered, i.e. the
#       number of commands which binding matched the event and that
#       worked properly.
#
# Side Effects:
#       None.
proc ::event::trigger { obj evt args } {
    variable log

    set bindings [__tobindings $obj]
    upvar \#0 $bindings BINDINGS

    set triggered 0
    if { [info exists $bindings] } {
	foreach {ptn cmd} $BINDINGS(bindings) {
	    if { [string match $ptn $evt] } {
		if { [catch {eval $cmd $obj $evt $args} res] } {
		    ${log}::warn "Error when invoking action '$cmd' bound to\
                                  event '$evt' on $obj: $res"
		} else {
		    incr triggered;  # Account as triggered
		}
	    }
	}
    }

    return $triggered
}



# ::event::generate -- Trigger an event, second type of event.
#
#       This procedure forms the core of the event triggering for
#       events of the second type.  It considers commands to contain
#       "sugar" that will be replaced at the time of the event,
#       similarly to Tk events.  The commands enforces three sugar
#       strings: %% will be replaced by a single %, %e will be
#       replaced by the name of the event, %o will be replaced by the
#       object on which the event occurs.  Any string that does NOT
#       start with % in the mapping construct will be ignored.
#
# Arguments:
#       obj	Identifier of the object on which the event occurs
#       evt	Name of the event that occurs.
#       arglist	List of pairs (think string map) for the argument mapping
#
# Results:
#       Return the number of commands that were triggered, i.e. the
#       number of commands which binding matched the event and that
#       worked properly.
#
# Side Effects:
#       None.
proc ::event::generate { obj evt { arglist {}} } {
    variable log

    set bindings [__tobindings $obj]
    upvar \#0 $bindings BINDINGS

    set triggered 0
    if { [info exists $bindings] } {
	foreach {ptn cmd} $BINDINGS(bindings) {
	    if { [string match $ptn $evt] } {
		# Construct internal forced mapping, and refuse
		# non-standard mappings.
		set argmap [list %% % %e $evt %o $obj]
		foreach {k v} $arglist {
		    if { [string index $k 0] ne "%" } {
			${log}::warn "$k does not start with a % in the\
                                      event mapping, ignoring!"
		    } else {
			lappend argmap $k $v
		    }
		}

		# Map command using constucted mapping and evaluate
		set cmd [string map $argmap $cmd]
		${log}::debug "Invoking bound command '$cmd' for event '$evt'\
                               on $obj"
		if { [catch {eval $cmd} res] } {
		    ${log}::warn "Error when invoking action '$cmd' bound to\
                                  event '$evt' on $obj: $res"
		} else {
		    incr triggered;  # Account as triggered.
		}
	    }
	}
    }

    return $triggered
}


package provide event 0.1