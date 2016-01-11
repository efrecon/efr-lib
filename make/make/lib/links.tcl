package require Tcl 8.4

package require platform

namespace eval ::linker {
    variable ML
    if { ![info exists ML] } {
	array set ML {
	    ln       "ln"
	    lnopts   "-s -f %src% %dst%"
	    initdone 0
	}
	variable libdir [file dirname [file normalize [info script]]]
    }
}

proc ::linker::__init {} {
    variable ML
    variable libdir

    # On windows, rely on the ln.exe from
    # http://www.flexhex.com/docs/articles/hard-links.phtml for making
    # the link instead, this avoids any dependency on cygwin or msys.
    # Note that ln -s on msys copies data instead of creating a
    # shortcut, which is why we had to rely on an external tool.

    set mkdir [file dirname [info script]]

    foreach {os cpu} [split [::platform::generic] "-"] break
    if { $os eq "windows" || $os eq "win32" } {
	set mklnk [auto_execok mkshortcut]
	if { $mklnk eq "" } {
	    set ML(ln) [file join [file normalize $libdir] \
			    .. bin Windows-x86 contrib ln "ln.exe"]
	    set ML(lnopts) "-s %src% %dst%"
	} else {
	    set ML(ln) $mklnk
	    set ML(lnopts) "-n %dst% %src%"
	}
    }
}


proc ::linker::symdir { root dir } {
    variable ML
    global tcl_platform

    if { ! $ML(initdone) } {
	__init
    }

    set target [file join $root $dir]
    if { ![file exists $target] } {
	if { ![file exists $root] } {
	    puts "$target nor $root exist!!!"
	    return 0
	} else {
	    set target $root
	}
    }

    set cmd [list exec $ML(ln)]
    set cmd [concat $cmd \
		 [string map \
		      [list %src% $target \
			   %dst% [file tail $target]] \
			   $ML(lnopts)]]

    if { [catch {eval $cmd} err] } {
	puts "Could not link to $target: $err"
    } else {
	puts "Link created: $dir -> $target"
    }
}


