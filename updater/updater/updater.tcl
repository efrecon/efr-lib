# updater.tcl -- Support for auto-update of programs
#
#	This module provides support for the automatic update of
#	programs and components.  To this end, it builds upon the
#	concept of contracts, which are tiny files that describe where
#	new versions of the program/component can be found and where
#	they should be installed.  Contracts can also be created from
#	the command line.  The module will update as soon as the MD5
#	announced on the remote location differs from the one that is
#	currently installed and pointed at by a contract.  Contracts
#	are lively and can be checked on a regular basis.
#
# Copyright (c) 2004-2007 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.4

package require uobj
package require process
package require massgeturl
package require diskutil
package require autoconnect

package require md5
package require uri

namespace eval ::updater {
    variable UPD
    if { ! [info exists UPD] } {
	array set UPD {
	    idgene            0
	    comments          "\#!;"
	    blocksize         65536
	    -source           ""
	    -sums             ""
	    -target           ""
	    -destroy          ""
	    -period           600
	    -install_attempts 5
	    -install_wait     500
	}
	variable libdir [file dirname [file normalize [info script]]]
	::uobj::install_log updater UPD; # Creates log namespace variable
	::uobj::install_defaults updater UPD; # Creates defaults procedure
    }
}

# The only type of "object" supported by this module are updater, or
# contracts as stated in the module description.  These are namespace
# variables which name starts with updater_ and is followed by an
# automated counter.  These variables are created via the
# ::updated::new command.  All indices started with a dash can be set
# via contract file reading or at creation time (creation might
# override the content of a file).  These indices have the following
# meaning:
#
# -source is a URL that points to the location where newer versions of
# the file should be placed.
#
# -sums is a (relative or absolute) URL that points to the location of
# a file that contains MD5 sums for (among others) the source.  When
# the URL is relative, it will be resolved to the URL of the source,
# which allows to keep the source and the sums in the same directory
# on a server.  The file can contain any number of lines (commented
# and empty lines being ignored) and is understood as follows: the
# first item in lines is the MD5 sum, the second a file name.  This
# file name will be matched against the one pointed at by the source.
# This (somewhat) complicated scheme allows to keep a number of
# sources and index these by a single MD5 sum description file if
# necessary.
#
# -target is the full path to where the remote file should be placed
# when the remote differs from the installed version.  The target
# recognises idioms such as %progdir% and %user%, the complete list
# being available from the ::diskutil::fname_resolv documentation.
# This allows for maximal flexibility.
#
# -destroy describes is the method that should be used for "removing"
# the component.  There are two methods that are currently supported:
# writing an (exit) command on a socket, or killing a process.  These
# are identified by the keywords SOCKET and KILL respectively.  Both
# methods can take additional arguments, which are simply whitespace
# separated arguments following the keyword.  SOCKET takes the port
# number to which the update module should connect (this will always
# be on the localhost); the remaining of the arguments forming the
# command to send on that socket (defaulting to EXIT).  KILL takes as
# arguments any number of strings that should be looked for when
# looking for the process to kill.  These default to the name of the
# target.  The first process identifiers matching these strings will
# be killed prior to installation.
#
# -period is the number of seconds to regularily check for new
# versions.  An empty string will lead to checking once only, i.e. at
# creation.
#
# -install_attempts is the number of times the updater tries to
# install the remote source onto the old version of the target.  The
# module tries several times in case resources are not completely
# freed immediately after the destruction procedure described above.
#
# -install_wait is the number of milliseconds to wait before
# installation attempts.


# ::updater::__digest -- Compute MD5 digest of a file
#
#	This procedure computes the MD5 digest of a file, acting like
#	::md5::md5 -hex -file.  The reason for this procedure to exist
#	is that computing the digest of a binary from that same binary
#	will have the disastrous effect to block for ever.  This
#	routine safely returns a digest in all situations (even though
#	it will be *erroneous* in the case described above).
#
# Arguments:
#	fname	Path to file
#
# Results:
#	The MD5 digest of the file in hexadecimal, or an empty string
#	on errors.
#
# Side Effects:
#	None.
proc ::updater::__digest { fname } {
    variable UPD
    variable log

    set md ""
    ${log}::info "Computing digest for file $fname"
    if { [catch {open $fname} fd] == 0 } {
	set mdid [::md5::MD5Init]
	fconfigure $fd -translation binary -encoding binary
	while { ! [eof $fd] } {
	    set dta [read $fd $UPD(blocksize)]
	    ::md5::MD5Update $mdid $dta
	}
	set md [::md5::Hex [::md5::MD5Final $mdid]]
	close $fd
    } else {
	${log}::warn "Could not open file at $fname: $fd"
    }

    return $md
}

# ::updater::__read -- Read updater contract
#
#	This procedure will read the content of a file and fill an
#	existing updater with this content.  The procedure is built so
#	as to only fill in dash-led options from the updater, and only
#	such that exist prior to calling it.  This enforces the
#	creation of default values.
#
# Arguments:
#	upd	Identifier of updater, as returned by ::updater::new
#	fname	Path to file to read
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::updater::__read { upd fname } {
    variable UPD
    variable log

    if { [info vars $upd] eq "" } {
	return -code error "$upd is not a known updater context"
    }

    upvar #0 $upd UPDATER

    ${log}::notice "Reading updater context from '$fname'"
    if { [catch {open $fname} fd] == 0 } {
	while { ! [eof $fd] } {
	    set line [string trim [gets $fd]]
	    if { $line ne "" } {
		set firstchar [string index $line 0]
		# Skip all lines that are commented.
		if { [string first $firstchar $UPD(comments)] < 0 } {
		    set key [lindex $line 0]
		    if { [string index $key 0] != "-" } {
			set key "-$key"
		    }
		    if { [lsearch [array names UPDATER -*] $key] < 0 } {
			${log}::warn "'$key' is an unrecognised key, skipping!"
		    } else {
			set UPDATER($key) [lrange $line 1 end]
		    }
		}
	    }
	}
	close $fd
    } else {
	${log}::error "Could not open file at $fname: $fd"
    }
}


# ::updater::__install -- Install new version
#
#	This procedure installs a newly downloaded new version of a
#	file onto the local disk.  The procedure will schedule a
#	finite number of installation attempts in order to cope with
#	failures.
#
# Arguments:
#	upd	Identifier of updater, as returned by ::updater::new
#	tgt	Path to file that contains the newer version
#	attempts	Number of attempts so far
#
# Results:
#	None.
#
# Side Effects:
#	Will copy tgt onto the destination file that is pointed at by
#	the updater contract.
proc ::updater::__install { upd tgt attempts} {
    variable UPD
    variable log

    if { [info vars $upd] eq "" } {
	return -code error "$upd is not a known updater context"
    }

    upvar #0 $upd UPDATER

    ${log}::debug "Trying to install $tgt into $UPDATER(destination)"
    if { [catch {file rename -force -- \
		     $tgt $UPDATER(destination)} err] } {
	${log}::warn "Could not copy new version into\
                      $UPDATER(destination): $err"
	incr attempts -1
	if { $attempts > 0 } {
	    after $UPDATER(-install_wait) \
		::updater::__install $upd "$tgt" $attempts
	} else {
	    ${log}::warn "Too many installation attempts, giving up"
	}
    } else {
	${log}::notice "Successfully installed new version at\
                        $UPDATER(destination)"
    }
}


proc ::updater::__copydone { upd tgt in_fd out_fd bytes {err {}} } {
    variable UPD
    variable log

    if { [info vars $upd] eq "" } {
	return -code error "$upd is not a known updater context"
    }

    upvar #0 $upd UPDATER

    close $in_fd
    close $out_fd
    if { [string length $err] != 0 } {
	${log}::warn "Error occurred during file copy: $err"
    } else {
	${log}::info "New file installed successfully into\
                      $UPDATER(destination)"
    }
    ${log}::debug "Deleting temporary copy of $UPDATER(-source) from $tgt"
    catch {file delete -force -- $tgt}
}


# ::updater::__downloaded -- Trigger destruction on download success
#
#	This procedure is called once the remote source of an updater
#	contract has been downloaded (or failed to).  On success, it
#	executes the destuction commands as pointed at by the -destroy
#	command and schedule installation of the new version that was
#	just downloaded.
#
# Arguments:
#	upd	Identifier of updater, as returned by ::updater::new
#	tgt	Path to file that contains the newer version
#	sum	MD5 sum of the file that we should have loaded
#	cxid	::massgeturl identifier
#	url	URL that was downloaded (probably the source)
#	status	Status of the download
#	token	Pointer to the content of the data
#
# Results:
#	None.
#
# Side Effects:
#	Will attempt to "kill" the locally running process according
#	to the method described in the contract and to install the new
#	version in place.
proc ::updater::__downloaded { upd tgt sum cxid url status token } {
    variable UPD
    variable log

    if { [info vars $upd] eq "" } {
	return -code error "$upd is not a known updater context"
    }

    upvar #0 $upd UPDATER
    if { $status eq "OK" } {
	# Check MD5 sum of downloaded file against what the server
	# said that we should have, discard on failure.
	set md5 [__digest $tgt]
	if { [string equal -nocase $md5 $sum] } {
	    ${log}::notice "Downloaded file from $url successful, trying to\
                            replace current file at $UPDATER(destination)"
	    set method [string toupper [lindex $UPDATER(-destroy) 0]]
	    set copyhandled 0
	    switch $method {
		"SOCKET" {
		    set port [lindex $UPDATER(-destroy) 1]
		    set cmd [lindex $UPDATER(-destroy) 2]
		    if { $cmd eq "" } {
			set cmd EXIT
		    }
		    ${log}::info "SOCKET method on port $port, command: $cmd"
		    ::autoconnect::send localhost:$port $cmd -autooff 1
		}
		"KILL" {
		    # Decide upon the strings that we should look for
		    # when looking for the processes among those that
		    # run.  We default to the name of the file we are
		    # updating with and without the extension.
		    set what [lrange $UPDATER(-destroy) 1 end]
		    if { $what eq "" } {
			set dst [file tail $UPDATER(destination)]
			set what [list $dst [file rootname $dst]]
		    }
		    ${log}::info "KILL method, looking for $what"

		    # Now look for the first matches for the string
		    # among the processes, stopping as soon as we have
		    # found some processes.
		    foreach dst $what {
			set pids [::process::find $dst]
			if { $pids ne "" } {
			    break
			}
		    }
		    
		    # Kill those processes (if we have some).  Make
		    # sure they really are dead by trying a (finite)
		    # number of times.
		    if { $pids eq "" } {
			${log}::warn "Could not find running any processes\
                                      matching $what!"
		    } else {
			set kill_attempts 10
			while { $kill_attempts > 0 && [llength $pids] > 0 } {
			    # Attempt to kill all the remaining pids
			    ::process::kill $pids

			    # Remove those that are not running
			    # anymore from the list of remaining pids.
			    set remaining [::process::list]
			    foreach p $pids {
				if { [lsearch $remaining $p] < 0 } {
				    ${log}::notice "Killed process $p"
				    set idx [lsearch $pids $p]
				    set pids [lreplace $pids $idx $idx]
				}
			    }

			    # Decrease counter in order to make sure
			    # we are going to end up trying to kill.
			    incr kill_attempts -1
			}
		    }
		}
		"INSTALL" {
		    # XXX: This is unfinished, non-working code.  An
		    # attempt to replace a binary in-situ.
		    if { [catch {open $UPDATER(destination) "w"} out_fd] } {
			${log}::warn "Could not open destination at\
                                      $UPDATER(destination): $out_fd"
		    } else {
			#seek $out_fd 0 start
			if { [catch {open $tgt} in_fd] } {
			    ${log}::warn "Could not open source at\
                                          $tgt: $in_fd"
			    close $out_fd
			} else {
			    set copyhandled 1
			    fconfigure $out_fd \
				-translation binary -encoding binary
			    fconfigure $in_fd \
				-translation binary -encoding binary
			    fcopy $in_fd $out_fd \
				-command [list ::updater::__copydone \
					      $upd $tgt $in_fd $out_fd]
			}
		    }
		}
		default {
		}
	    }

	    # Schedule installation of the file onto the local disk.
	    if { ! $copyhandled } {
		after idle \
		    ::updater::__install $upd "$tgt" $UPDATER(-install_attempts)
	    }
	} else {
	    ${log}::warn "Downloaded file at $tgt corrupt, removing it"
	    catch {file delete -force -- $tgt}
	}
    } else {
	${log}::warn "Failed to fetch new version from $url"
    }
}


proc ::updater::__dn_progress { upd cxid furl url current total } {
    variable log

    ${log}::debug "$furl: Fetched $current bytes of $total"
}

# ::updater::__checksums -- Compute check sums and trigger download
#
#	This procedure is called when the remote check sums file has
#	been downloaded.  It looks for the check sum of the source and
#	verifies it against the one of the file on disk.  On
#	difference, it triggers the download of the new file, which
#	will then proceed with the update.
#
# Arguments:
#	upd	Identifier of updater, as returned by ::updater::new
#	cxid	::massgeturl identifier
#	url	URL that was downloaded (probably the MD5 file)
#	status	Status of the download
#	token	Pointer to the content of the data
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::updater::__checksums { upd cxid url status token } {
    variable UPD
    variable log

    if { $status eq "OK" } {
	if { [info vars $upd] eq "" } {
	    return -code error "$upd is not a known updater context"
	}

	upvar #0 $upd UPDATER

	# Decide of the name of the file on the remote server
	array set src [::uri::split $UPDATER(-source)]
	set src_fname [file tail $src(path)]

	# Decide of the destination on the local disk.  If that is a
	# directory, append it the same name as the file on the remote
	# server (the most usual case).
	set dst [::diskutil::fname_resolv $UPDATER(-target)]
	if { [file isdirectory $dst] } {
	    set dst [file join $dst $src_fname]
	}
	set UPDATER(destination) $dst

	# Now parse the result, i.e. the content of the MD5 sum file
	# coming from the server.
	upvar #0 $token result
	foreach line [split $result(body) "\n"] {
	    if { $line ne "" } {
		set firstchar [string index $line 0]
		# Skip all lines that are commented.
		if { [string first $firstchar $UPD(comments)] < 0 } {
		    set sum [lindex $line 0]
		    set fname [lrange $line 1 end]
		    # We have found a file name that matches the one
		    # from the contract.  Compute MD5 of file on local
		    # disk and trigger downloading of remote source if
		    # they are different.
		    if { $fname eq $src_fname } {
			${log}::debug "Computing MD5 for local file $dst"
			set md5 [__digest $dst]
			if { ! [string equal -nocase $md5 $sum] } {
			    set tgt [::diskutil::temporary_file updater \
					 [file extension $UPDATER(destination)]]
			    ${log}::notice "New version available for\
                                            $UPDATER(destination), downloading\
                                            into $tgt and replacing"
			    ::massgeturl::infile $UPDATER(-source) $tgt \
				[list ::updater::__downloaded $upd $tgt $sum] \
				-progress [list ::updater::__dn_progress $upd]
			} else {
			    ${log}::debug "$dst still has MD5 $sum at remote"
			}
		    }
		}
	    }	    
	}
    } else {
	${log}::warn "Could not get the MD5 sums at $url"
    }
}


# ::updater::check -- Check for update
#
#	Check for updates for the file pointed at by an updater contract
#
# Arguments:
#	upd	Identifier of updater, as returned by ::updater::new
#	period	Period to use for periodical updates (in seconds)
#
# Results:
#	None.
#
# Side Effects:
#	Will schedule a periodical check whenever the period is specified.
proc ::updater::check { upd { period "" } } {
    variable UPD
    variable log

    if { [info vars $upd] eq "" } {
	return -code error "$upd is not a known updater context"
    }

    upvar #0 $upd UPDATER
    set sums [::uri::resolve $UPDATER(-source) $UPDATER(-sums)]
    ::massgeturl::get $sums [list ::updater::__checksums $upd] \
	-progress [list ::updater::__dn_progress $upd]

    if { $period ne "" } {
	${log}::debug "Scheduling next check in $period secs."
	set pms [expr $period * 1000]
	set UPDATER(next) [after $pms ::updater::check $upd $period]
    }
}


# ::updater::config -- Get/set updater configuration options
#
#	LongDescr.
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
proc ::updater::config { upd args } {
    variable UPD
    variable log

    if { [info vars $upd] eq "" } {
	${log}::warn "$upd is not a known updater context"
	return -code error "$upd is not a known updater context"
    }

    upvar #0 $upd UPDATER
    set result [eval ::uobj::config UPDATER "-*" $args]

    if { $UPDATER(next) eq "" } {
	set UPDATER(next) [after idle ::updater::check $upd $UPDATER(-period)]
    }

    return $result
}


# ::updater::new -- Create a new live updater
#
#	LongDescr.
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
proc ::updater::new { fname args } {
    variable UPD
    variable log

    set upd [namespace current]::updater_[incr UPD(idgene)]
    upvar #0 $upd UPDATER

    set UPDATER(id) $upd
    set UPDATER(start) [clock seconds]
    set UPDATER(next) ""
    ::uobj::inherit UPD UPDATER

    if { $fname ne "" } {
	::updater::__read $upd $fname
    }

    eval config $upd $args

    return $upd
}


package provide updater 0.1
