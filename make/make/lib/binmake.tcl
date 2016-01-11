# binmake.tcl -- Support for Making self-contained binaries
#
#	This module provides support for the production of
#	self-contained binaries via tclkit.  It is designed to pick up
#	the necessary libraries necessary for a given binary from a
#	number of different locations and putting all these into a
#	single (temporary) folder for the making of the kit and
#	binary.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.


package require Tcl 8.4

package require argutil
package require platform

namespace eval ::binmake {
    variable BM
    if { ! [info exists BM] } {
	array set BM {
	    dt_fmt       "%Y%m%d"
	    minver       7
	    maxver       9
	}
	variable libdir [file dirname [file normalize [info script]]]
    }
}

# ::binmake::platform -- Return platform unique identification
#
#       This command forms a unique string for the platform on which
#       the current interpreter is running.  The string contains not
#       only the operating system, but also the CPU architecture.
#       This implementation originates from critcl (I think).
#       Examples of returned strings are Windows-x86, Linux-x86 or
#       Darwin-ppc
#
# Arguments:
#	none
#
# Results:
#	Returns a unique platform identification string.
#
# Side Effects:
#	None.
proc ::binmake::platform {} {
    global tcl_platform

    set plat [lindex $tcl_platform(os) 0]
    set mach $tcl_platform(machine)
    switch -glob -- $mach {
	sun4* { set mach sparc }
	intel -
	i*86* { set mach x86 }
	"Power Macintosh" { set mach ppc }
    }
    switch -- $plat {
	AIX   { set mach ppc }
	HP-UX { set mach hppa }
    }
    return "$plat-$mach"
}


# ::binmake::__findfirst -- Lookup dir content by patterns
#
#	This procedure looks up the content of a directory and returns
#	the first file that matches one of the patterns passed as a
#	parameter.
#
# Arguments:
#	d	Path to directory
#	ptn_l	List of patterns
#
# Results:
#	Return the first file that matches one of the patterns.  The
#	patters are examined in their order and only one file will be
#	returned.
#
# Side Effects:
#	None.
proc ::binmake::__findfirst { d { ptn_l "*" } } {
    foreach p $ptn_l {
	set f [lindex [glob -nocomplain -directory $d $p] 0]
	if { $f ne "" } {
	    return $f
	}
    }
    return ""
}


# ::binmake::directories -- Tcl installation directories detection
#
#	This procedure detects the various directories of a Tcl
#	installation
#
# Arguments:
#	version	Preferred Tcl version for the tclkit binaries
#
# Results:
#	Returns a tuple-list ready for an array set
#	command with the information about the installation.
#
# Side Effects:
#	None.
proc ::binmake::directories { { version "8.5.8" } } {
    variable BM
    variable libdir

    set dirs(mkroot) [file join $libdir ..]
    set dirs(bindir) [file join $dirs(mkroot) bin [platform] $version]
    set dirs(toolsdir) [file join $dirs(mkroot) bin [platform] contrib]
    set dirs(winkit) \
	[__findfirst $dirs(bindir) \
	     [list tclkit-*.upx.exe tclkit.upx.exe tclkit-*.exe]]
    set dirs(shkit) \
	[__findfirst $dirs(bindir) \
	     [list tclkitsh-*.upx.exe tclkitsh.upx.exe tclkitsh-*.exe]]
    set dirs(sdx) [file join $dirs(mkroot) kits sdx.kit]

    set dirs(til) [file join $::argutil::libdir ..]
    set dirs(core) [info library]
    set dirs(bi) [file join $dirs(core) ..]

    # Find the top directory for where the teapot packages are
    # installed, from there get to the ones that are generic (i.e. not
    # Tcl modules, but rather packages), the one that contain binary
    # (for that platform) and then enumerate the directories that
    # could be found containing Tcl modules so we can find them.  Note
    # that finding modules these way might pose backward compatibility
    # issues since we are going back in time a lot. Maybe do we want
    # to keep to the same major version number as the one for the
    # version that was passed as an argument.
    set dirs(pots) [file join $dirs(core) .. teapot package]
    set dirs(pot) [list \
		       [file join $dirs(pots) tcl lib] \
		       [file join $dirs(pots) [::platform::identify] lib]]
    for {set main $BM(minver)} { $main <= $BM(maxver) } { incr main } {
	for { set sub 0 } { $sub < 10 } { incr sub } {
	    foreach pkg { tcl tk } {
		set d [file join $dirs(pots) $pkg teapot \
			   ${pkg}${main} ${main}.${sub}]
		if { [file isdirectory $d] } {
		    lappend dirs(pot) $d
		}
	    }
	}
    }

    # Find the places that can contain the til and tklib, at the
    # highest version if relevant and several found.
    foreach {vernum path} [::argutil::searchlib tcllib \
			       [list $dirs(bi) $dirs(core) \
				    [file join $dirs(til) ..]]] break
    set dirs(tcllib) $path
    foreach {vernum path} [::argutil::searchlib tklib \
			       [list $dirs(bi) $dirs(core) \
				    [file join $dirs(til) ..]]] break
    set dirs(tklib) $path

    return [array get dirs]
}


# ::binmake::kit -- Make a kit
#
#	This procedure gathers all the necessary elements for the
#	construction of a tclkit for an application.  These elements
#	are taken both from the current tcl installation and from the
#	unkitted version of the application to be made.  Note that
#	specific attention is paid to Tcl modules, as these are placed
#	under the site-tcl directory in the kit so they can be found
#	by a package require as from within the application.
#
# Arguments:
#	topdir	Top directory containing the application
#	app	Name of the application (and main script)
#	args	List of dash led options and values
#
# Results:
#	Return the name of the tclkit that was generated
#
# Side Effects:
#	Creates a temporary directory for gathering all necessary
#	elements on the disks (under the top directory) and generates
#	a tclkit.
proc ::binmake::kit { topdir app args } {
    variable BM

    # TODO: Maybe do we actually want to make a distinction between
    # site-tcl and non site.  Things that would come from core
    # components such as the batteries included packages, the core,
    # etc. could be installed there, which "local" stuff, less
    # official (the til, internal libraries, etc.) could be installed
    # as at present, i.e. in the lib directory.

    # Use default or forced version.
    array set opts $args
    if { [array names opts -version] ne "" } {
	puts "Forcing version $opts(-version) !"
	array set dirs [directories $opts(-version)]
    } else {
	array set dirs [directories]
    }
    set version [clock format [clock seconds] -format $BM(dt_fmt)]
    set tmpdir [file join $topdir tmp${version}_${app}]

    set curdir [pwd]
    file delete -force $tmpdir
    file mkdir $tmpdir

    file copy -force ${app}.tcl $tmpdir

    cd $tmpdir
    puts "Initializing kit: ${app}.kit"
    mexec $dirs(shkit) $dirs(sdx) qwrap ${app}.tcl
    mexec $dirs(shkit) $dirs(sdx) unwrap ${app}.kit

    if { [array names opts -extras] ne "" } {
	puts "Installing extra files and/or directories..."
	foreach f $opts(-extras) {
	    puts "  $f -> ${app}.vfs"
	    file copy -force [file join $topdir $f] ${app}.vfs
	}
    }

    if { [array names opts -tcllib] ne "" } {
	puts "Installing tcllib modules..."
	foreach m $opts(-tcllib) {
	    puts "  $m -> ${app}.vfs/lib"
	    file copy -force [file join $dirs(tcllib) $m] ${app}.vfs/lib
	}
    }
    if { [array names opts -tklib] ne "" } {
	puts "Installing tklib modules..."
	foreach m $opts(-tklib) {
	    puts "  $m -> ${app}.vfs/lib"
	    file copy -force [file join $dirs(tklib) $m] ${app}.vfs/lib
	}
    }
    if { [array names opts -tclbi] ne "" } {
	puts "Installing batteries included modules..."
	foreach m $opts(-tclbi) {
	    puts -nonewline "  $m -> ${app}.vfs/lib"
	    foreach {vernum src} [::argutil::searchlib $m $dirs(bi)] break
	    if { $src ne "" } {
		file copy -force $src ${app}.vfs/lib
		puts ""
	    } else {
		puts "  !! Cannot find $m !!"
	    }
	}
    }

    if { [array names opts -tclpot] ne "" } {
	puts "Installing teapot controlled modules..."
	foreach m $opts(-tclpot) {
	    puts -nonewline "  $m -> ${app}.vfs/lib"
	    foreach {vernum src} [::argutil::searchlib $m $dirs(pot)] break
	    if { $src ne "" } {
		if { [file extension $src] eq ".tm" } {
		    # XX: Use which version number here, the one from
		    # the interpreter used for "compiling" or the one
		    # from the default or forced version of the
		    # destination kit.
		    foreach {major minor} [split $::tcl_version "."] break
		    file mkdir ${app}.vfs/lib/tcl${major}/site-tcl
		    file copy -force $src ${app}.vfs/lib/tcl${major}/site-tcl
		    puts " (module! copied into site-tcl)"
		} else {
		    file copy -force $src ${app}.vfs/lib
		    puts ""
		}
	    } else {
		puts "  !! Cannot find $m !!"
	    }
	}
    }

    if { [array names opts -tclcore] ne "" } {
	puts "Installing Tcl core modules..."
	foreach m $opts(-tclcore) {
	    puts -nonewline "  $m -> ${app}.vfs/lib"
	    foreach {vernum src} [::argutil::searchlib $m $dirs(core)] break
	    if { $src ne "" } {
		file copy -force $src ${app}.vfs/lib
		puts ""
	    } else {
		puts "  !! Cannot find $m !!"
	    }
	}
    }

    if { [array names opts -lib] ne "" } {
	puts "Installing local library modules..."
	foreach m $opts(-lib) {
	    puts -nonewline "  $m -> ${app}.vfs/lib"
	    set src [::argutil::resolve_links [file join .. lib $m]]
	    if { $src ne "" } {
		foreach fname [glob -- $src] {
		    file copy -force $fname \
			[file join ${app}.vfs lib [file dirname $m]]
		}
		puts ""
	    } else {
		puts "  !! Cannot find $m !!"
	    }
	}
    }

    if { [array names opts -til] ne "" } {
	puts "Installing til modules..."
	file mkdir ${app}.vfs/lib/til
	file mkdir ${app}.vfs/lib/til/bin
	foreach m $opts(-til) {
	    puts "  $m -> ${app}.vfs/lib/til"
	    file copy -force [file join $dirs(til) $m] ${app}.vfs/lib/til
	}
	puts "  argutil.tcl -> ${app}.vfs/lib/til/bin"
	file copy -force [file join $dirs(til) bin argutil.tcl] \
	    ${app}.vfs/lib/til/bin
    }

    if { [array names opts "-copydone"] ne "" } {
	catch {eval $opts(-copydone) [file normalize ${app}.vfs]}
    }

    puts "Wrapping all files into kit ${app}.kit"
    mexec $dirs(shkit) $dirs(sdx) wrap ${app}.kit
    file rename -force ${app}.kit ..
    cd $curdir
    if { [array names opts "-keep"] eq "" || [string is false $opts(-keep)] } {
	puts "Removing temporary directory '$tmpdir'"
	file delete -force $tmpdir
    }

    return ${app}.kit
}


# ::binmake::__makerc -- Generates an RC file
#
#	This procedure generates an RC file from a number of
#	arguments.  If only one argument is given, only an application
#	icon information will be added (with the value of that
#	argument), otherwise, the following arguments will be
#	recognised: anything that end with icons (note the pluralis)
#	will lead to an icon information under that specification, so
#	for the default icon of your application, you will have to
#	specify 'appicons'; description is the file description,
#	company is the name of your company, version will be the
#	file/product version, copyright is the copyright notice,
#	product is the name of the product.
#
# Arguments:
#	rcfname	Path to RC file to create
#	args	Key value like list of arguments.
#
# Results:
#	None.
#
# Side Effects:
#	Creates an RC file on the disk
proc ::binmake::__makerc { rcfname args } {
    variable BM
    variable libdir

    if { [catch {open $rcfname w} fd] } {
	puts "Could not open $rcfname for writing: $fd"
	return
    }

    if { [llength $args] == 1 } {
	set icofname $args
	puts $fd "APPICONS ICON\
                  \"[file nativename [file normalize $icofname]]\""
    } else {
	array set nfo $args
	foreach iconfo [array names nfo *icons] {
	    puts $fd "[string toupper $iconfo] ICON\
                      \"[file nativename [file normalize $nfo($iconfo)]]\""
	}
	
	# Generate a compatible (4 numbers) version number
	set version 1.0.0.0
	if { [array names nfo version] ne "" } {
	    set version $nfo(version)
	    set vl [split $version "."]
	    lappend vl 0 0 0 0
	    set vl [lrange $vl 0 3]
	    set version [join $vl .]
	}
	set rcversion [join [split $version .] ", "]

	puts $fd "1 VERSIONINFO"
	puts $fd "FILEVERSION $rcversion"
	puts $fd "PRODUCTVERSION $rcversion"
	puts $fd "FILEOS 4"
	puts $fd "FILETYPE 1"
	puts $fd "{"
	puts $fd "\tBLOCK \"StringFileInfo\" {"
	puts $fd "\t\tBLOCK \"040904b0\" {"
	if { [array names nfo descr] ne "" } {
	    puts $fd "\t\t\tVALUE \"FileDescription\", \"$nfo(descr)\""
	}
	if { [array names nfo company] ne "" } {
	    puts $fd "\t\t\tVALUE \"CompanyName\", \"$nfo(company)\""
	}
	puts $fd "\t\t\tVALUE \"FileVersion\", \"$version\""
	if { [array names nfo copyright] ne "" } {
	    puts $fd "\t\t\tVALUE \"LegalCopyright\", \"$nfo(copyright)\""
	}
	if { [array names nfo product] ne "" } {
	    puts $fd "\t\t\tVALUE \"ProductName\", \"$nfo(product)\""
	}
	puts $fd "\t\t\tVALUE \"ProductVersion\", \"$version\""
	puts $fd "\t\t}"
	puts $fd "\t}"
	puts $fd "\tBLOCK \"VarFileInfo\" {"
	puts $fd "\t\tVALUE \"Translation\", 0x0409, 0x04B0"
	puts $fd "\t}"
	puts $fd "}"
    }

    close $fd
}


# ::binmake::executable -- Make an executable
#
#	This procedure transforms a tclkit (typically made using the
#	::kit procedure above) into a proper platform dependant
#	executable.  On windows, the procedure is able to arrange for
#	an icon and a number of information resources to be amended to
#	the binary.
#
# Arguments:
#	topdir	Top directory containing the application
#	app	Name of the application
#	type	Type of the final binary to make (console or gui).
#               Note that specific version number to use can be appended
#               after a colon sign.
#
# Results:
#	Return the name of the executable that was generated
#
# Side Effects:
#	Creates a temporary directory for unpacking the incoming kit
#	and for the modification of the kit binaries (under the top
#	directory) and generates a binary executable
proc ::binmake::executable { topdir app type args } {
    variable BM

    # Extract the (forced) version number to use for the final
    # executable from after the colon sign in the application type, if
    # any.  This will force the executable to be using the tclkit at
    # that version
    foreach {type version} [split $type ":"] break
    if { $version eq "" } {
	array set dirs [directories]
    } else {
	array set dirs [directories $version]
    }
    set version [clock format [clock seconds] -format $BM(dt_fmt)]
    set tmpdir [file join $topdir tmp${version}_${app}]
    
    if { $type eq "gui" } {
	set rt $dirs(winkit)
    } else {
	set rt $dirs(shkit)
    }

    set curdir [pwd]
    file delete -force $tmpdir
    file mkdir $tmpdir
    # Make the RC file now to be able to access possibly relative path
    # for the icons (the RC file construction normalizes the path)
    if { [llength $args] > 0 } {
	eval __makerc [file join $tmpdir ${app}.rc] $args
    }

    file copy -force ${app}.kit $tmpdir
    cd $tmpdir

    mexec $dirs(shkit) $dirs(sdx) unwrap ${app}.kit
    file copy -force $rt [file tail $rt]
    if { [llength $args] > 0 } {
	if { [string first "upx" $rt] >= 0 } {
	    mexec [file join $dirs(toolsdir) upx upx.exe] -q -d [file tail $rt]
	    mexec [file join $dirs(toolsdir) ResHacker ResHacker.exe] \
		-delete [file tail $rt],tclkit-win32.exe,icongroup,,
	    file rename -force tclkit-win32.exe [file tail $rt]
	    if { [llength $args] > 1} {
		mexec [file join $dirs(toolsdir) ResHacker ResHacker.exe] \
		    -delete [file tail $rt],tclkit-win32.exe,versioninfo,,
		file rename -force tclkit-win32.exe [file tail $rt]
	    }
	    mexec [file join $dirs(toolsdir) GoRC GoRC.exe] /r /no $app
	    mexec [file join $dirs(toolsdir) ResHacker ResHacker.exe] \
		-add [file tail $rt],tclkit-win32.exe,${app}.res,,,
	    file rename -force tclkit-win32.exe [file tail $rt]
	    mexec [file join $dirs(toolsdir) upx upx.exe] -q [file tail $rt]
	}
    }
    mexec $dirs(shkit) $dirs(sdx) wrap ${app}.exe -runtime [file tail $rt]
    file rename -force ${app}.exe ..
    cd $curdir
    file delete -force $tmpdir

    return ${app}.exe
}


