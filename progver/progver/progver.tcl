package require Tcl 8.4

namespace eval ::progver {
    variable VERSION
    if { ! [info exists VERSION] } {
	array set VERSION {
	    -ext          ".vsn"
	    version       ""
	    -max          4
	    -sublen       3
	}
    }
}


proc ::progver::__pad { version } {
    variable VERSION

    set vl [split $version "."]
    for { set i 0 } { $i < $VERSION(-max) } { incr i } {
	lappend vl 0
    }
    return [join [lrange $vl 0 [expr $VERSION(-max) - 1]] "."]
}

proc ::progver::__check { version } {
    variable VERSION

    set vl [split $version "."]
    if { $vl > $VERSION(-max) } {
	return -code error \
	    "Too many version sub tokens, no more than $VERSION(-max)\
             is accepted!"
    }

    foreach v $vl {
	if { ![string is integer $v] } {
	    return -code error "Version sub token '$v' is not an integer!"
	}
    }

    return [__pad $version]
}


proc ::progver::greater { version } {
    variable VERSION
    
    if { $VERSION(version) eq "" } {
	version [guess]; # Give a try with default options...
	if { $VERSION(version) eq "" } {
	    return -code error "Program without official version yet!"
	}
    }


    set version [__check $version]
    set vcheck ""
    foreach vt [split $version "."] {
	append vcheck [format "%.$VERSION(-sublen)i" $vt]
    }
    set current ""
    foreach vt [split $VERSION(version) "."] {
	append current [format "%.$VERSION(-sublen)i" $vt]
    }

    return [expr $current >= $vcheck]
}


proc ::progver::version { version } {
    variable VERSION

    set VERSION(version) [__check $version]
    return $VERSION(version)
}


proc ::progver::guess { { progname "" } } {
    variable VERSION

    set dirs [list [pwd]]
    set version ""

    if { $progname eq "" } {
	if { [info exists ::starkit::topdir] } {
	    set prgpath $::starkit::topdir
	} else {
	    set prgpath $::argv0
	}
	
	set progdir [file dirname $prgpath]
	set progname [file rootname [file tail $prgpath]]
	
	lappend dirs $progdir
	if { [info exists ::starkit::topdir] } {
	    lappend dirs $::starkit::topdir
	}
    }
    
    foreach d $dirs {
	set ext [string trimleft $VERSION(-ext) "."]
	set fname [file join $d ${progname}.$ext]
	if { [file exists $fname] } {
	    if { [catch {open $fname} fd] == 0 } {
		set version [string trim [read $fd]]
		close $fd
		break
	    }
	}
    }

    return $version
}

package provide progver 0.2