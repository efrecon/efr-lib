# license.tcl -- Simple License Support
#
#	This module provides simple support for licensing.  The idea
#	is to read a license file that contains one or more licenses
#	for any number of products.  Licenses can be temporary (and
#	thus expire).  Products have version numbers, and minor
#	revisions are given for free (and thus should pass the license
#	check).  The algorithm is based on a simple check sum with
#	some random salt.  This is far from complex, but should resist
#	people that simply try.  The module provides support for a
#	customer "database", i.e. a file that contains customer
#	identifiers, which are automatically generated for new
#	customers.  This idea is however not mandatory and you could
#	use any integer for the customer id.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.4

package require uobj
package require md5

namespace eval ::license {
    variable LC
    if { ! [info exists LC] } {
	array set LC {
	    -product      ""
	    -version      1.0
	    -name         ""
	    -email        ""
	    -organisation ""
	    -customer     ""
	    -expiration   ""
	    -exit         on
	    seed          ""
	    maxrndseps    10
	    algo_ver      1
	    comments      "\#!;"
	    separator     "|"
	    secret        "Change this to any secret pass, long is best!"
	    dt_fmt        "%m/%d/%Y %H:%M"
	    generator     {algo_ver -product -version -expiration -customer -name -email -organisation}
	}
	variable libdir [file dirname [file normalize [info script]]]
	::uobj::install_log [namespace current] LC; # Creates 'log' variable
	::uobj::install_defaults [namespace current] LC
    }
}


# ::license::__srand -- Initialise local pseudo-random sequence
#
#	This procedure initialises the local pseudo-random sequence
#	and act similarily as srand().
#
# Arguments:
#	seed	Seed to initialise with
#
# Results:
#	Return a number between 0.0 and 1.0
#
# Side Effects:
#	None.
proc ::license::__srand { { seed "" } } {
    variable LC
    variable log

    if { $seed == "" } {
	set seed [expr {[clock clicks] + [pid]}]
    }
    set LC(seed) [expr {$seed % 259200}]
    return [expr {double($LC(seed)) / 259200}]
}



# ::license::__rand -- Return next pseudo-random in sequence
#
#	This procedure computes the next pseudo-random number from the
#	sequence and returns it.
#
# Arguments:
#	None.
#
# Results:
#	Return a number between 0.0 and 1.0
#
# Side Effects:
#	None.
proc ::license::__rand { } {
    variable LC
    variable log

    if { $LC(seed) == "" } {
	return [__srand]
    }

    set LC(seed) [expr {($LC(seed) * 7141 + 54773) % 259200}]
    return [expr {double($LC(seed)) / 259200}]
}


# ::license::__save_userdb -- Save user database
#
#	This procedure saves the user database which content is
#	contained in the variable passed as an argument.  The user
#	database is a private document that contains all the
#	identifiers that are assigned to customers.
#
# Arguments:
#	db_p	Pointer to user database array
#	fname	Full path to user database
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::license::__save_userdb { db_p fname } {
    variable LC
    variable log

    upvar $db_p DB

    ${log}::info "Saving user database to $fname"
    if { [catch {open $fname w} fd] == 0 } {
	foreach id [lsort [array names DB]] {
	    foreach {name email org} $DB($id) break
	    puts $fd "$id \{$name\} \{$email\} \{$org\}"
	}
	close $fd
    } else {
	${log}::error "Could not open $fname for writing: $fd"
    }
}


# ::license::__read_userdb -- Read user database
#
#	This procedure reads the content of the user database which
#	file path is passed as a parameter.  The user database is a
#	private document that contains all the identifiers that are
#	assigned to customers.
#
# Arguments:
#	db_p	Pointer to user database array
#	fname	Full path to user database
#
# Results:
#	Return the number of users that were inserted in the database
#
# Side Effects:
#	None.
proc ::license::__read_userdb { db_p fname } {
    variable LC
    variable log

    upvar $db_p DB

    ${log}::info "Opening user database: $fname"
    set nb_users 0
    if { [catch {open $fname} fd] == 0 } {
	while { ! [eof $fd] } {
	    set line [string trim [gets $fd]]
	    if { $line ne "" } {
		set firstchar [string index $line 0]
		if { [string first $firstchar $LC(comments)] < 0 } {
		    foreach {id name email org} $line break
		    if { [string is integer $id] } {
			set DB($id) [list "$name" "$email" "$org"]
			incr nb_users
		    } else {
			${log}::warn "$id is not a valid user identifier"
		    }
		}
	    }
	}
	close $fd
    } else {
	${log}::error "Could not open user database at $fname: $fd"
    }

    return $nb_users
}


# ::license::__keygen -- License key generation
#
#	This procedure generates a license key for the information
#	that is contained in the array passed as a parameter.  This is
#	your secret weapon, don't tell anyone :-)
#
# Arguments:
#	info_p	"pointer" to license information support.
#
# Results:
#	Return the license key
#
# Side Effects:
#	None.
proc ::license::__keygen { info_p } {
    variable LC
    variable log

    upvar $info_p LINFO

    set key [__srand $LINFO(-customer)]
    foreach idx $LC(generator) {
	append key $LINFO($idx)
	set nb [expr int([__rand]*$LC(maxrndseps))]
	for {set i 0} {$i<$nb} {incr i} {
	    append key [__rand]
	}
    }
    append key $LC(secret)
    set key [string toupper [::md5::md5 -hex $key]]

    return $key
}


# ::license::generate -- Generate a license line
#
#	This procedure generates a license line for a given product at
#	a given version for a given user (all being specified via the
#	dash led options given to this procedure).
#
# Arguments:
#	userdb  Path to user database for customer identifier
#	        generation, if empty you will have to provide an id
#               yourself.
#	args	Dash led options and values for generation (see doc)
#
# Results:
#	Return the license (line) or an empty string on errors.
#
# Side Effects:
#	None.
proc ::license::generate { userdb args } {
    global argv0
    variable LC
    variable log

    ::uobj::inherit LC LINFO $LC(generator)
    array set LINFO $args
    if { $LINFO(-product) eq "" } {
	set LINFO(-product) [file tail $argv0]
    }

    if { $LINFO(-customer) eq "" } {
	array set UDB {}
	__read_userdb UDB $userdb
	set maxid ""
	set found 0
	foreach id [array names UDB] {
	    if { $maxid eq "" || $UDB($id) > $maxid } {
		set maxid $UDB($id)
	    }
	    foreach {name email org} $UDB($id) break
	    if { [string eq $name $LINFO(-name)] \
		     && [string eq $email $LINFO(-email)] \
		     && [string eq $org $LINFO(-organisation)] } {
		set found 1
		break
	    }
	}
	
	if { $found } {
	    set LINFO(-customer) $id
	} else {
	    if { $maxid eq "" } {
		set maxid 0
	    }
	    set LINFO(-customer) [incr maxid]
	    set UDB($maxid) \
		[list "$LINFO(-name)" "$LINFO(-email)" "$LINFO(-organisation)"]
	    __save_userdb UDB $userdb
	}
    }

    if { ![string is integer $LINFO(-customer)] } {
	${log}::error "$LINFO(-customer) is not a valid customer ID"
	return ""
    }
    
    set lver [split $LINFO(-version)]
    if { [llength $lver] > 3 } {
	${log}::error "$LINFO(-version) is not a valid version number"
	return ""
    }
    
    if { $LINFO(-expiration) ne "" } {
	if { [catch {clock scan $LINFO(-expiration)} exp] } {
	    ${log}::error "$LINFO(-expiration) is not a valid expiration date"
	    return ""
	}
	set LINFO(-expiration) [clock format $exp -format $LC(dt_fmt)]
    }

    set license ""
    foreach idx $LC(generator) {
	append license $LINFO($idx)
	append license $LC(separator)
    }
    append license [__keygen LINFO]

    return $license
}


# ::license::add -- Add a license to a file
#
#	This procedure generates a license line using
#	::license::generate and append this license to the file which
#	path is passed as an argument.
#
# Arguments:
#	fname	Path to license file
#	userdb	Path to user database (see above)
#	args	Dash led options and values for the license generation
#
# Results:
#	A positive number on success, 0 otherwise
#
# Side Effects:
#	None.
proc ::license::add { fname userdb args } {
    variable LC
    variable log

    set license [eval generate $userdb $args]
    if { $license eq "" } {
	${log}::error "Could not generate license!"
	return 0
    }

    ${log}::info "Saving new license database to $fname"
    if { [catch {open $fname a} fd] == 0 } {
	puts $fd $license
	close $fd
    } else {
	${log}::error "Could not open $fname for writing: $fd"
	return 0
    }

    return 1
}


# ::license::check -- Check license validity
#
#	This procedure checks the validity of a product against a
#	license file, typically generated by ::license::add.  The
#	procedure can, if instructed, exit the whole application on
#	license mismatch.
#
# Arguments:
#	fname	Path to license file
#	args    Dash led options and values specifying the current
#	        product (to be checked against the license file).
#
# Results:
#	The function will return the list of keys that matched for the
#	product specified.  An empty list means that this is an
#	illegal product.
#
# Side Effects:
#	Illegal product detection will usually led to the end of the
#	application, unless you have specified -exit off when calling
#	this procedure.
proc ::license::check { fname args } {
    variable LC
    variable log

    ::uobj::inherit LC PINFO [list -product -version -exit]
    array set PINFO $args
    if { $PINFO(-product) eq "" } {
	set PINFO(-product) [file tail $argv0]
    }

    ${log}::info "Opening license file: $fname"
    set lineno 0
    set matchkeys [list]
    set now [clock seconds]
    if { [catch {open $fname} fd] == 0 && [file mtime $fname] < $now } {
	while { ! [eof $fd] } {
	    set line [string trim [gets $fd]]
	    incr lineno
	    if { $line ne "" } {
		set firstchar [string index $line 0]
		if { [string first $firstchar $LC(comments)] < 0 } {
		    # Fill LINFO with license information from line
		    set l [split $line $LC(separator)]
		    if { [llength $l] != [expr [llength $LC(generator)]+1] } {
			${log}::info "Format error at line \#$lineno"
			continue
		    }
		    for {set i 0} {$i<[llength $LC(generator)]} {incr i} {
			set LINFO([lindex $LC(generator) $i]) [lindex $l $i]
		    }
		    set LINFO(key) [lindex $l end]
		    
		    # Cross check run-time version against license algo version
		    if { $LINFO(algo_ver) != $LC(algo_ver) } {
			${log}::info \
			    "Licensing version mismatch at line \#$lineno"
			continue
		    }

		    # Check product types
		    if { $LINFO(-product) ne $PINFO(-product) } {
			continue
		    }

		    # Check version numbers
		    set lver [split $LINFO(-version) .]
		    set pver [split $PINFO(-version) .]
		    if { [llength $lver] > 3 || [llength $pver] > 3 } {
			${log}::info "Format error at line \#$lineno"
			continue
		    }
		    # Skip lines with different major revision number
		    # than ours, they are not interesting.
		    if { [lindex $lver 0] != [lindex $pver 0] } {
			continue
		    }
		    # Minor revisions are given for free, so enable
		    # newer binary on an old license
		    set minor_l [join [lrange $lver 1 2] .]
		    set minor_p [join [lrange $pver 1 2] .]
		    if { $minor_p < $minor_l } {
			continue
		    }

		    # Check customer id.
		    if { ! [string is integer $LINFO(-customer)] } {
			${log}::info "Format error at line \#$lineno"
			continue
		    }

		    # Expiration date
		    if { $LINFO(-expiration) ne "" } {
			if { [catch {clock scan \
					 $LINFO(-expiration)} expiration] } {
			    ${log}::info "Format error at line \#$lineno"
			    continue
			}
			if { [clock seconds] > $expiration } {
			    continue
			}
		    }

		    # Now generate check sum
		    set key [__keygen LINFO]
		    if { $key ne $LINFO(key) } {
			${log}::info "Invalid license at line \#$lineno"
		    } else {
			lappend matchkeys $key
		    }
		}
	    }
	}
	close $fd
    } else {
	${log}::error "Could not open license file at $fname: $fd"
    }

    if { [llength $matchkeys] <= 0 } {
	${log}::error "No valid license found!"
	if { [string is true $PINFO(-exit)] } {
	    exit
	}
    }

    return $matchkeys
}


package provide license 0.1
