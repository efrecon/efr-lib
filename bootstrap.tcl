##################
## Module Name     --  bootstrap.tcl
## Original Author --  Emmanuel Frecon - emmanuel@sics.se
## Description:
##
##     TIL bootstrapping utility.  This package aims at looking for
##     the "argutil.tcl" main file that most TIL-based utilities should
##     initially source.  This file is aimed at being sourced directly at
##     the beginning of your programs and it will look for and
##     automatically load the services offered by argutil.  Apart for
##     looking for argutil, the main functionality provided by the
##     bootstrapping package is to resolve windows shell links to real
##     places on the disk, which facilitates development via cygwin on
##     windows and allows the reuse of a single TIL directory tree between
##     applications.
##
## Commands Exported:
##	::bootstrap::bootstrap
##################
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.


package provide bootstrap 1.0


namespace eval ::bootstrap {
    variable BS
    if { ! [info exists BS] } {
        array set BS {
            levels     "debug info notice warn error critical"
            loglevel   warn
            dateformat "%d%m%y %H:%M:%S"
            dft_outfd  stdout
            autostart  on
            initdone   off
            agu_path   ""
            vbs_path   ""
            -maxlinks  10
        }
    }
    namespace export bootstrap
}


# ::bootstrap::__out -- Output log information to console
#
#       This command dumps log information to an opened file
#       descriptor.  The command can also take a file name, in which
#       case it will append the log string to the file.  The
#       implementation of fix_outlog sees to re-route all log dumping
#       from the logger module to this command, that will, as such,
#       act as a central hub.
#
# Arguments:
#	service	Name of the logger service
#	level	Log level at which the output happens
#	str	Information being logged
#	dt	Current date (in seconds since epoch), empty means now
#	fd_nm	File descriptor/name to which to dump, empty means default
#
# Results:
#	None.
#
# Side Effects:
#	Dump to the file descriptor
proc ::bootstrap::__out { service level str { dt "" } { fd_nm "" } } {
    variable BS
    
    # Store current date in right format
    if { $dt eq "" } {
        set dt [clock seconds]
    }
    set logdt [clock format $dt -format $BS(dateformat)]
    
    # Now guess if fd_nm is a file descriptor or the name of a
    # file. If it is a file name, try to open it.
    if { $fd_nm eq "" } {
        set fd_nm $BS(dft_outfd)
    }
    if { [catch {fconfigure $fd_nm}] } {
        # fconfigure will scream if the variable is not a file
        # descriptor, in that case, it is a file name!
        if { [catch {open $fd_nm a+} fd] } {
            __out bootstrap warn "Cannot open $fd_nm for writing: $fd"
            set fd ""
        }
    } else {
        set fd $fd_nm
    }
    
    # Now that we are here, fd contains where to output the string.
    # It can be empty if we could not open the file when the input was
    # a file name.
    if { $fd ne "" } {
        if { [catch {puts $fd "\[$logdt\] \[$service\] \[$level\] '$str'"}] } {
            __out bootstrap warn "Cannot write to log file descriptor $fd!"
        }
        if { $fd ne $fd_nm } {
            # Close the output file if the parameter was a name.
            close $fd
        }
    }
}


# ::bootstrap::log -- Internal log function
#
#       This command log internal information from this package
#       through either the logger module, as soon as it is present,
#       either through the output facility.  The command installs a
#       new logger service as soon as the logger module has been
#       loaded.
#
# Arguments:
#	level	Log level for this information
#	str	Information being logged
#
# Results:
#	None.
#
# Side Effects:
#	Will possibly create a new logger service.
proc ::bootstrap::log { lvl str } {
    variable BS
    
    set au_lvl [lsearch $BS(levels) $BS(loglevel)]
    set cur_lvl [lsearch $BS(levels) $lvl]
    if { $cur_lvl >= $au_lvl } {
        __out bootstrap debug $str
    }
}



# ::bootstrap::__readlnk_vbs -- Read link content via VBS
#
#       This procedure creates a VB script that read the content of
#       windows shortcuts and return the target for a given shortcut.
#       The technique fails over to the old introspection method when
#       script creation does not work.
#
# Arguments:
#       lnk	Path to windows shortcut
#
# Results:
#       Returns target of shortcut
#
# Side Effects:
#       Creates a temporary VBS on disk.
proc ::bootstrap::__readlnk_vbs { lnk } {
    variable BS
    global env
    
    # First try among some well-known environment variables for a
    # temporary directory
    set tmpdir ""
    if { [array names env "TEMP"] == "TEMP" } {
        set tmpdir $env(TEMP)
    } elseif { [array names env "TMP"] == "TMP" } {
        set tmpdir $env(TMP)
    } elseif { [array names env "TMPDIR"] == "TMPDIR" } {
        set tmpdir $env(TMPDIR)
    } elseif { [array names env "USERPROFILE"] == "USERPROFILE" } {
        set tmpdir [file join $env(USERPROFILE) "Local Settings" "Temp"]
    } elseif { [array names env "WINDIR"] == "WINDIR" } {
        set tmpdir [file join $env(WINDIR) "Temp"]
    } elseif { [array names env "SYSTEMROOT"] == "SYSTEMROOT" } {
        set tmpdir [file join $env(SYSTEMROOT) "Temp"]
    } else {
        set tmpdir [cwd]
    }
    
    set tgt ""; # Link target
    set fname [file join $tmpdir bootstrap_[pid].vbs]
    if { [catch {open $fname [list WRONLY CREAT]} fd] == 0 } {
        # We (re)create the VBS for conversion, this is a bit
        # overkill, but only 5 lines, so it should do and simplifies
        # the code.
        fconfigure $fd -translation crlf
        puts $fd "Dim WSHShell"
        puts $fd "Set WSHShell = WScript.CreateObject(\"WScript.Shell\")"
        puts $fd "Set WshSysEnv = WshShell.Environment(\"PROCESS\")"
        puts $fd "Set myShortcut = WSHShell.CreateShortcut(Wscript.Arguments.Item(0))"
        puts $fd "WScript.Echo myShortcut.TargetPath"
        close $fd
        set BS(vbs_path) $fname;  # Remember it to be able to cleanup later
        
        # Run the VBS script and gather result.
        set cmd "|cscript //nologo \"$fname\" \"$lnk\""
        set fl [open $cmd]
        set tgt [read $fl]
        if { [catch {close $fl} err] } {
            log error "Could not read content of link: $lnk"
        }
        set tgt [string trim $tgt]
    }
    
    if { $tgt eq "" } {
        log warn "Failed with VBS for conversion, trying introspection"
        set fp [open $lnk]
        fconfigure $fp -encoding binary -translation binary -eofchar {}
        foreach snip [split [read $fp] \x00] {
            set abssnip [file join [file dirname $lnk] $snip]
            if { $snip ne "" && [file exists $abssnip]} {
                log info "'$abssnip' found in '$lnk', using it as the link!"
                set tgt $snip
                break
            }
        }
        close $fp
    }
    
    return $tgt
}

# ::bootstrap::__readlnk -- Read the target of a windows shell link
#
#       This command command uses tcom (if possible) or an homebrew
#       solution to attempt reading the content of a windows shell link and
#       returns the target.
#
# Arguments:
#	lnk	Path to shell link
#
# Results:
#	Path to target or error.
#
# Side Effects:
#	Will attempt to load tcom.
proc ::bootstrap::__readlnk { lnk } {
    if { ![file exists $lnk] } {
        log warn "'$lnk' is not an accessible file"
        return -code error "'$lnk' is not an accessible file"
    }
    
    if { [catch {package require twapi} err] == 0 } {
        log debug "'twapi' available, trying most modern method first"
        array set shortcut [::twapi::read_shortcut $lnk]
        log info "'$lnk' points to '$shortcut(-path)'"
        return $shortcut(-path)
    } elseif { [catch {package require tcom} err] == 0 } {
        log debug "'tcom' available trying failsafe method first"
        set sh [::tcom::ref createobject "WScript.Shell"]
        set lobj [$sh CreateShortcut [file nativename $lnk]]
        set tgt [$lobj TargetPath]
        log info "'$lnk' points to '$tgt'"
        if { $tgt ne "" } {
            return $tgt
        }
    } else {
        log debug "Could not find 'twapi' or 'tcom' package: $err"
        return [__readlnk_vbs $lnk]
    }
    
    return ""
}


# ::bootstrap::__resolve_links -- Resolve links
#
#       This command will resolve windows shell links that are
#       contained in a path to their real location on the disk.
#
# Arguments:
#	path	local path to file
#
# Results:
#	Returns a resolved path to the file or an error if the file
#	does not exist
#
# Side Effects:
#	None.
proc ::bootstrap::resolve_links { path } {
    global tcl_platform
    variable BS
    
    if { $tcl_platform(platform) eq "windows" } {
        for { set i 0 } { $i < $BS(-maxlinks) } { incr i } {
            set rp ""
            set sp [file split $path]
            foreach d $sp {
                set jp [file join $rp $d]
                if { [string toupper [file extension $jp]] eq ".LNK" } {
                    log debug "Resolving sub path at $jp"
                    set rp [file join $rp [__readlnk $jp]]
                } elseif { [file exists ${jp}.lnk] } {
                    log debug "Resolving sub path at ${jp}.lnk"
                    set rp [file join $rp [__readlnk ${jp}.lnk]]
                } else {
                    set rp $jp
                }
            }
            if { $rp eq $path } {
                break
            }
            set path $rp
        }
        log info "Resolved '$path' to '$rp'"
        return $rp
    } else {
        return $path
    }
}


# ::bootstrap::bootstrap -- Bootstrap TIL based programs
#
#       This command bootstraps TIL based programs through finding the
#       argument parsing utilities.
#
# Arguments:
#	None
#
# Results:
#	The path of the bootstrap.tcl that was read and sourced
#
# Side Effects:
#	Source bootstrap.tcl
proc ::bootstrap::bootstrap { } {
    variable BS
    
    if { ! [string is true $BS(initdone)] } {
        global argv0
        
        # Build a list of library path from within which we should look
        # for the sub directory of the TIL.
        set rootdirs [list [file dirname [info script]] [file dirname $argv0]]
        set path_search {}
        foreach rd $rootdirs {
            foreach d [list [file join .. .. .. lib til bin] \
                    [file join .. .. lib til bin ] \
                    [file join .. lib til bin ] \
                    [file join lib til bin ] \
                    [file join .. .. .. til bin] \
                    [file join .. .. til bin] \
                    [file join .. til bin]] {
                lappend path_search [file join $rd $d]
            }
        }
        log debug "Looking for argutil in '$path_search'"
        
        # Test one directory after the other from the previous list
        # after the bootstrap file that we will source to bootstrap the
        # library.
        foreach p $path_search {
            set agu [file join [resolve_links $p] argutil.tcl]
            if { [file exists $agu] } {
                if { [catch {source "$agu"} err] } {
                    log error \
                            "Found argutil in $agu, but could not source: $err!"
                } else {
                    log notice "Found argutil at '$agu'"
                    set BS(initdone) on
                    set BS(agu_path) $agu
                    break
                }
            }
        }
    }
    
    # Clean VBS temp file, if necessary
    if { $BS(vbs_path) ne "" && [file exists $BS(vbs_path)] } {
        file delete -force -- $BS(vbs_path)
        log info "Cleaned away temporary VBS for link target conversion"
        set BS(vbs_path) ""
    }
    
    return $BS(agu_path)
}

# Bootstrap everything by automatically calling the bootstraping
# procedure.
if { $::bootstrap::BS(autostart) } {
    ::bootstrap::bootstrap
}

