# wprocess.tcl -- ShortDescr
#
#	This module provides an interface to work with processes on
#	windows.  It is built on top of the winapi module and does not
#	require the help of any external process as the module in TIL.
#	This module has exactly the same programming interface, which
#	allows it to completely replace the one provided by the TIL.
#
# Copyright (c) 2007 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
package require Tcl 8.4
package require logger

package require winapix
package require uobj

namespace eval ::process {
    variable WPS
    global tcl_platform

    if {![info exists WPS]} {
	array set WPS {
	}
	variable libdir [file dirname \
			     [::diskutil::absolute_path [info script]]]
	::uobj::install_log [namespace current] WPS; # Creates 'log' variable
    }

    namespace export loglevel find list full_list kill
}

# ::process::find --
#
#	Find one or several running processes whose name match a given
#	regular expression.
#
# Arguments:
#	rgx	Regular expression to match (defaults to all processes)
#
# Results:
#	Return a list (possibly empty) of process identifiers.
#
# Side Effects:
#	None.
proc ::process::find { { rgx "" } } {
    variable WPS
    variable log

    ${log}::info "Directly getting process list"

    set pids [::list]
    set h [::winapi::CreateToolhelp32Snapshot SNAPPROCESS 0]
    if { $h < 0 } {
	${log}::error "No processes in snapshot"
    } else {
	set nfo [::winapi::Process32First $h]
	while { $nfo ne "" } {
	    array set info $nfo
	    if { [regexp $rgx $info(ExeFile)] } {
		lappend pids $info(ProcessID)
	    }
	    set nfo [::winapi::Process32Next $h]
	}
	::winapi::CloseHandle $h
    }
    return $pids
}


# ::process::list --
#
#	List all currently running processes.
#
# Arguments:
#	None.
#
# Results:
#	Return a list (possibly empty) of all running process identifiers.
#
# Side Effects:
#	None.
proc ::process::list {} {
    variable WPS
    variable log

    ${log}::info "Directly getting process list"

    set pids [::list]
    set h [::winapi::CreateToolhelp32Snapshot SNAPPROCESS 0]
    if { $h < 0 } {
	${log}::error "No processes in snapshot"
    } else {
	set nfo [::winapi::Process32First $h]
	while { $nfo ne "" } {
	    array set info $nfo
	    lappend pids $info(ProcessID)
	    set nfo [::winapi::Process32Next $h]
	}
	::winapi::CloseHandle $h
    }
    return $pids
}

# ::process::full_list --
#
#	Lists all currently running system processes.  The list is a
#	list of list with the following content (in that order and
#	whenever possible, otherwise an empty string): process id,
#	user, program, ppid, vmsize
#
# Arguments:
#	None.
#
# Results:
#	Return a list (possibly empty) with information for all
#	running processes.
#
# Side Effects:
#	None.
proc ::process::full_list { } {
    variable WPS
    variable log

    ${log}::info "Directly getting process list"

    set pids [::list]
    set h [::winapi::CreateToolhelp32Snapshot SNAPPROCESS 0]
    if { $h < 0 } {
	${log}::error "No processes in snapshot"
    } else {
	set nfo [::winapi::Process32First $h]
	while { $nfo ne "" } {
	    array set info $nfo
	    lappend pids [::list $info(ProcessID) "" $info(ExeFile) \
			      $info(ParentProcessID) ""]
	    set nfo [::winapi::Process32Next $h]
	}
	::winapi::CloseHandle $h
    }
    return $pids
}

# ::process::kill --
#
#	Kill a list of given processes.
#
# Arguments:
#	pids	List of processes to kill
#
# Results:
#	Return a list of processes for which the kill command successed.
#
# Side Effects:
#	Will actively attempt to kill processes that are external to
#	this process!
proc ::process::kill { pids } {
    variable WPS
    variable log

    ${log}::info "Directly killing processes $pids"
    set killed [::list]
    foreach pid $pids {
	${log}::debug "Directly killing process $pid"
	::winapi::KillProcess $pid
	lappend killed $pid
    }
    return $killed
}

package provide wprocess 0.1
