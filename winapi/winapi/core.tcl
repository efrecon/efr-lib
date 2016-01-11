# core.tcl -- Core procedures of the winapi module.
#
#	This module provides a number of helper functions for the
#	implementation of the winapi module.  These are mainly
#	functions to automatically define callouts of WIN32 functions
#	in Tcl and conversion functions of various sorts.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.2
package require logger

# We need Ffidl since we will be creating loads of callouts
package require Ffidl

namespace eval ::winapi::core {
    variable WINAPI
    if { ! [info exists WINAPI] } {
	array set WINAPI {
	    loglevel   warn
	    dft_dlls   "user32.dll kernel32.dll winmm.dll"
	    inited     {}
	}
	variable log [::logger::init [string trimleft [namespace current] ::]]
	${log}::setlevel $WINAPI(loglevel)
    }
}

# ::winapi::core::loglevel -- Set/Get current log level.
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
proc ::winapi::core::loglevel { { loglvl "" } } {
    variable WINAPI
    variable log

    if { $loglvl != "" } {
	if { [catch "${log}::setlevel $loglvl"] == 0 } {
	    set WINAPI(loglevel) $loglvl
	}
    }

    return $WINAPI(loglevel)
}


# ::winapi::core::flag -- Transcript a textual flag to its integer value
#
#	This procedure looks in a flag list for a given flag and
#	return the (integer) value that is associated to it.  The flag
#	specification list is any repetition of key value where the
#	key is ready for string matching.  Matching on incoming flag
#	and keys is made careless of the case.
#
# Arguments:
#	f	Flag to convert to integer
#	specs	List of specification key1 val1 key2 val2 ...
#
# Results:
#	Returns the first matching value of the flag, if the flag was
#	already an integer it is returned, empty flags will lead to 0.
#
# Side Effects:
#	None.
proc ::winapi::core::flag { f specs { pure 0 } } {
    # Empty flag
    if { [string length $f] == 0 } {
	return 0
    }

    # Already an integer, return it
    if { !$pure && [string is integer $f] } {
	return $f
    }

    # Otherwise look for first matching key in specification list and
    # return it.
    set f [string toupper $f]
    foreach {spec val} $specs {
	if { [string match [string toupper $spec] $f] } {
	    return $val
	}
    }

    return 0
}


# ::winapi::core::tflag -- Transcript an integer constant to its textual value
#
#	This procedure looks in a flag list for a given flag and
#	return the (textual) value that is associated to it.  The flag
#	specification list is any repetition of key value where the
#	key is ready for string matching.
#
# Arguments:
#	f	Flag to convert to string
#	specs	List of specification key1 val1 key2 val2 ...
#
# Results:
#	Returns the first matching value of the flag
#
# Side Effects:
#	None.
proc ::winapi::core::tflag { f specs } {
    foreach {spec val} $specs {
	if { $val == $f } {
	    return $spec
	}
    }
    return ""
}

# ::winapi::core::flags -- Transcript a textual flag to its integer value
#
#	This procedure looks in a flag list for several flags (like a
#	C masked flag) and return the (integer) value that is
#	associated to them.  The flag specification list is any
#	repetition of key value where the key is ready for string
#	matching.  Matching on incoming flag and keys is made careless
#	of the case.
#
# Arguments:
#	f	List of flags to convert to integer
#	specs	List of specification key1 val1 key2 val2 ...
#
# Results:
#	Returns the added value of all flags (which is equivalent to
#	an OR operation), if the flag was already an integer it is
#	returned, empty flags will lead to 0.
#
# Side Effects:
#	None.
proc ::winapi::core::flags { flagsl specs } {
    # Empty flag, 0
    if { [string length $flagsl] == 0 } {
	return 0
    }

    # Otherwise perform the addition
    set flags 0
    foreach f $flagsl {
	incr flags [flag $f $specs]
    }

    return $flags
}


# ::winapi::core::tflags -- Transcript an integer mask flag to its string list
#
#	This procedure considers the incoming integer as a flag mask
#	and return the list of textual value that is associated to
#	them.  The flag specification list is any repetition of key
#	value where the key is ready for string matching.
#
# Arguments:
#	f	Flag mask to convert to list of values
#	specs	List of specification key1 val1 key2 val2 ...
#
# Results:
#	Returns the list of flags contained in the mask, empty possibly
#
# Side Effects:
#	None.
proc ::winapi::core::tflags { f specs } {
    set vals ""
    foreach {spec val} $specs {
	if { [expr {$f & $val}] } {
	    lappend vals $spec
	}
    }
    return $vals
}


# ::winapi::core::strrepeat -- String repeater
#
#	This procedure repeats a string a given number of times,
#	placing an optional sepatator between each repeation and
#	returns the result as a new string.
#
# Arguments:
#	s	String to repeat
#	nb	Number of repetitions
#	sep	Separator to place in between each repetition.
#
# Results:
#	A new string.
#
# Side Effects:
#	None.
proc ::winapi::core::strrepeat { s nb { sep "" } } {
    set str ""
    for { set i 0 } { $i < $nb } { incr i } {
	append str $s
	if { $i < [expr {$nb - 1}] } {
	    append str $sep
	}
    }
    return $str
}


# ::winapi::core::api -- Declare callout for DLL functions.
#
#	This procedure declares a callout in this namespace for a
#	given function from one DLL.
#
# Arguments:
#	apiname	Name of command to be created (::winapi:: will be prefixed)
#	argl	List of arguments to the callout
#	ret	Type of value returned
#	dllname	Name of corresponding function in DLL (empty means same as api)
#	dll	DLL in which to get the function from
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::winapi::core::api { apiname argl ret { dllname "" } { dll "" } } {
    variable WINAPI
    variable log

    if { $dllname == "" } {
	set dllname $apiname
	# Get rid of lead underscore whenever possible.
	if { [string match "__*" $dllname] } {
	    set dllname [string range $dllname 2 end]
	}
    }

    # Look for the function by its name, alernatively by its name
    # followed by the letter "A" as it seems the case sometimes.
    if { $dll == "" } { set dll $WINAPI(dft_dlls) }
    set addr ""
    foreach l $dll {
	if { [string is true $::winapi::WINAPI(unicode)] } {
	    set dlls [list $dllname ${dllname}W]
	} else {
	    set dlls [list $dllname ${dllname}A]
	}
	foreach n $dlls {
	    if { [catch {::ffidl::symbol $l $n} addr] } {
		set addr ""
	    } else {
		break
	    }
	}
	if { $addr != "" } { break }
    }
    if { $addr != "" } {
	::ffidl::callout ::winapi::$apiname $argl $ret $addr
    } else {
	${log}::info "Could not find '$dllname' in $dll"
    }
}


# ::winapi::core::adddll -- Add a default dll
#
#	This command sees to add another default dll for consideration
#	when looking for functions using the api declaration
#	procedure.
#
# Arguments:
#	dll	New dll, with or without extension
#
# Results:
#	Return the name of the dll on success, an empty string otherwise.
#
# Side Effects:
#	None.
proc ::winapi::core::adddll { dll } {
    variable WINAPI
    variable log

    set dll [string tolower $dll]
    if { [file extension $dll] ne ".dll" } {
	append dll ".dll"
    }

    ${log}::notice "Adding $dll to default windows API declaration DLLs"
    set idx [lsearch $WINAPI(dft_dlls) $dll]
    if { $idx < 0 } {
	lappend WINAPI(dft_dlls) $dll
    }

    return $dll
}


# ::winapi::core::makelong -- Make a long
#
#	Make a long from the low and high words
#
# Arguments:
#	l	Low word
#	h	High word
#
# Results:
#	Return the constructed long
#
# Side Effects:
#	None.
proc ::winapi::core::makelong { l h } {
    variable WINAPI
    variable log

    return [expr ($l & 0xFFFF) + (($h & 0xFFFF) * 0x10000)]
    return [expr ($l & 0xffff) | (($h & 0xffff) << 16)]
}


# ::winapi::core::makewparam -- Make a windows message wparam
#
#	Make a wparam from the low and high words
#
# Arguments:
#	l	Low word
#	h	High word
#
# Results:
#	Return the constructed wparam
#
# Side Effects:
#	None.
proc ::winapi::core::makewparam { l h } {
    return [makelong $l $h]
}


# ::winapi::core::makelparam -- Make a windows message lparam
#
#	Make a lparam from the low and high words
#
# Arguments:
#	l	Low word
#	h	High word
#
# Results:
#	Return the constructed lparam
#
# Side Effects:
#	None.
proc ::winapi::core::makelparam { l h } {
    return [makelong $l $h]
}


# ::winapi::core::makelresult -- Make a lresult
#
#	Make a lresult from the low and high words
#
# Arguments:
#	l	Low word
#	h	High word
#
# Results:
#	Return the constructed lresult
#
# Side Effects:
#	None.
proc ::winapi::core::makelresult { l h } {
    return [makelong $l $h]
}


# ::winapi::core::initonce -- Initialise sub-modules once only
#
#	This procedure contains code to initialise sub-modules
#	(typically the various modules of the winapi implementation)
#	once only.  The command passed as argument is called, it
#	should either return the name of the module or a true boolean
#	on success.
#
# Arguments:
#	module	Name of module
#	cmd	Command to execute
#
# Results:
#	1 on initialisation success, 0 otherwise
#
# Side Effects:
#	None.
proc ::winapi::core::initonce { module cmd } {
    variable WINAPI
    variable log

    if { [lsearch $WINAPI(inited) $module] <= 0 } {
	set failed 0
	if { [catch {eval $cmd} res] } {
	    ${log}::critical "Could not initialise module $module: $res"
	} else {
	    if { $res == "" } {
		set failed 1
	    } elseif { $res ne $module && [string is false $res] } {
		set failed 1
	    }
	}

	if { $failed } {
	    ${log}::error "Could not initialise module $module"
	} else {
	    lappend WINAPI(inited) $module
	}

	return $failed
    } else {
	return 1
    }
}


package provide winapi::core 0.2
