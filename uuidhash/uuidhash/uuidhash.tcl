package require Tcl 8.4

namespace eval ::uuidhash {
    variable UUIDHASH
    if { ! [info exists UUIDHASH] } {
	array set UUIDHASH {
	    generator  ""
	}
    }
}


proc ::uuidhash::__init {} {
    variable UUIDHASH

    if { ! [catch {package require sha1} ver] } {
	set UUIDHASH(generator) sha1
    } elseif { ! [catch {package require md5} ver] } {
	set UUIDHASH(generator) md5
    }
    return $UUIDHASH(generator)
}


proc ::uuidhash::uuid { str } {
    variable UUIDHASH

    if { $UUIDHASH(generator) eq "" } {
	if { [::uuidhash::__init] eq "" } {
	    return -code error "Cannot find an appropriate UUID generator"
	}
    }

    set uid ""
    set version 0
    switch $UUIDHASH(generator) {
	md5 {
	    set uid [string tolower [::md5::md5 -hex $str]]
	    set version 3
	}
	sha1 {
	    set uid [string tolower [::sha1::sha1 -hex $str]]
	    set version 5
	}
    }

    if { $uid ne "" } {
	return "[string range $uid 0 7]-[string range $uid 8 11]-${version}[string range $uid 13 15]-[string range $uid 16 19]-[string range $uid 20 31]"
    }
    return ""; # Should never be reached.
}


package provide uuidhash 1.0