# license_generator.tcl -- Command-line License generation
#
#	LongerDescr
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.


array set LG {
    inheritance "product name email organisation version expiration"
    finished    0
}

source [file join [file dirname [info script]] .. bootstrap.tcl]
argutil::accesslib tcllib

# Now parse the options and put the result into the global state array
package require cmdline

set options {
    { product.arg "" "Product name" }
    { name.arg "" "User full name" }
    { email.arg "" "User email address" }
    { organisation.arg "" "User's organisation/affiliation" }
    { version.double "1.0" "Version number" }
    { expiration.arg "" "Expiration date for license (empty means forever)" }
    { userdb.arg "%progdir%/userdb.dat" "Path to user database" }
    { license.arg "" "Path to license file to generate/amend" }
    { verbose.arg "warn" "Verbosity Level" }
}

set inited [argutil::initargs LG $options]
if { [catch {cmdline::typedGetoptions argv $options} optlist] != 0 } {
    puts [cmdline::typedUsage $options "accepts the following options:"]
    exit
}

array set LG $optlist
foreach key $inited {
    argutil::makelist LG($key)
}

# Include modules that we depend on.  This is complicated to be able
# to address separately modules in the verbose specification.
argutil::accesslib til
argutil::accesslib license
argutil::loadmodules [list diskutil license] $LG(verbose)

# Initialise local logging facility
package require logger
set LG(log) [::logger::init [file rootname [file tail [info script]]]]
$LG(log)::setlevel $LG(verbose)


argutil::fix_outlog

foreach idx $LG(inheritance) {
    set LINFO(-$idx) $LG($idx)
}

if { $LG(license) eq "" } {
    puts [eval ::license::generate [::diskutil::fname_resolv $LG(userdb)] \
	      [array get LINFO]]
} else {
    eval ::license::add [::diskutil::fname_resolv $LG(license)] \
	[::diskutil::fname_resolv $LG(userdb)] [array get LINFO]
}

