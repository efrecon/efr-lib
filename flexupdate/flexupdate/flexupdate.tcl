# flexupdate.tcl -- Flexible replacement for "update" command
#
#	This module provides a replacement for the update command so
#	that callers can call it as much as they want and so that the
#	real update command is only called once in a while.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl

package require uobj
package require logger

namespace eval ::flexupdate {
    variable UPD
    if { ! [info exists UPD] } {
	array set UPD {
	    verbose           warn
	    installed         0
	    lastupdate        0
	    lastidle          0
	    -triggeridle      0
	    -trigger          75
	    -fallback         off
	}
	variable libdir [file dirname [file normalize [info script]]]
	::uobj::install_log flexupdate UPD; # Creates log namespace variable
	::uobj::install_defaults flexupdate UPD; # Creates defaults procedure
    }
}


# ::flexupdate::update -- Update Replacement
#
#	This command keeps a state of when the true update was called
#	last time and will only call it if a given number of
#	milliseconds have elapsed.  It does the same for update
#	idletasks.  The command can fall back to only do idle tasks
#	when calls to update are block because of a too short time
#	period.
#
# Arguments:
#	idletasks	Non empty will mean idletasks
#
# Results:
#	Returns one of NOTHING, IDLETASKS or UPDATE depending on what was
#	done.
#
# Side Effects:
#	None.
proc ::flexupdate::update { { idletasks "" } } {
    variable UPD
    variable log

    set now [clock clicks -milliseconds]
    if { $idletasks ne "" } {
	set elapsed [expr {$now - $UPD(lastidle)}]
	if { $elapsed >= $UPD(-trigger) } {
	    ${log}::debug "$elapsed ms since last idletasks update, updating"
	    set UPD(lastidle) $now
	    if { $UPD(installed) } {
		__origupdate idletasks
	    } else {
		::update idletasks
	    }
	    return IDLETASKS
	}
    } else {
	set elapsed [expr {$now - $UPD(lastupdate)}]
	if { $elapsed >= $UPD(-trigger) } {
	    set UPD(lastupdate) $now
	    ${log}::debug "$elapsed ms since last update, updating"
	    if { $UPD(installed) } {
		__origupdate idletasks
	    } else {
		::update
	    }
	    return UPDATE
	} elseif { [string is true $UPD(-fallback)] } {
	    return [update idletasks]; # Our own implementation, recurse.
	}
    }
    
    return NOTHING
}


# ::flexupdate::__update -- Bridge Update caller
#
#	This command is meant to be what the regular update is renamed
#	to.  It simply passes forward the argument to our own internal
#	implementation.  This is so as to code our update easier (in
#	the namespace).
#
# Arguments:
#	args	All arguments blindly passed to update
#
# Results:
#	Return the result of update
#
# Side Effects:
#	None.
proc ::flexupdate::__update { args } {
    return [eval ::flexupdate::update $args]
}


# ::flexupdate::takeover -- Replace regular update
#
#	This procedure sees to replace the regular Tcl update command
#	with our implementation above.
#
# Arguments:
#	None.
#
# Results:
#	None.
#
# Side Effects:
#	All calls to update will be re-routed to this module
proc ::flexupdate::takeover {} {
    variable UPD
    variable log

    if { ! $UPD(installed) } {
	${log}::info "Re-routing calls to update into flexupdate"
	rename ::update ::flexupdate::__origupdate
	rename ::flexupdate::__update ::update
	set UPD(installed) 1
    }

    return $UPD(installed)
}


# ::flexupdate::release -- Restore regular update
#
#	This procedure sees to restore the regulate Tcl update command.
#
# Arguments:
#	None
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::flexupdate::release {} {
    variable UPD
    variable log

    if { $UPD(installed) } {
	${log}::info "Restoring normal update behaviour"
	rename ::update ::flexupdate::__update
	rename ::flexupdate::__origupdate ::update
	set UPD(installed) 0
    }

    return $UPD(installed)
}

package provide flexupdate 0.1
