##################
## Module Name     --  translate
## Original Author --  Emmanuel Frécon - emmanuel.frecon@myjoice.com
## Description:
##
##     This module aims at generating and updating a number of
##     language catalogue files for an application.  The module is
##     able to remove messages that are not needed anymore and to add
##     new translations that might have appeared.
##
## Commands Exported:
##      ::translate::update
##################

package require Tcl 8.5

package require msgcat

namespace eval ::translate {
    variable TRANS
    if { ! [info exists TRANS] } {
	array set TRANS {
	    -ignore      {pkgIndex.tcl}
	    -files       *.tcl
	    -languages   {en}
	    -source      en
	}
	variable libdir [file dirname [file normalize [info script]]]
    }
}


# ::translate::__translate -- 
#
#       This procedure is a re-write of the code at
#       http://wiki.tcl.tk/14377.  It parses a number of Tcl files for
#       all occurrences of translatable messages, i.e. as led by the
#       mc, ::msgcat::mc or msgcat::mc commands and generates an
#       output file for the language that is passed as a parameter.
#       The procedure is able to handle old translations and will
#       remove old translations and add new ones to the main catalogue
#       file.
#
# Arguments:
#       msgdir	Directory where to place language files.
#       src	Source language, i.e. language used in the files
#       dst	Destination language, i.e. language to produce catalogue for
#       files	List of files to parse and analyse.
#
# Results:
#       Return the number of messages that is contained in the
#       destination file.
#
# Side Effects:
#       (over)write target destination language file
proc ::translate::__translate { msgdir src dst files } {
    variable TRANS

    set dst_fname [file join $msgdir ${dst}.msg]
    set src_fname [file join $msgdir ${src}.msg]
    if { [file exists $dst_fname] } {
	# Keep old translation, just in case
	set old "[file rootname [file tail $dst_fname]].old"
	puts "Keeping old translation as $old"
	file copy -force -- $dst_fname \
	    [file join [file dirname $dst_fname] $old]
	source -encoding utf-8 $dst_fname; # use existing translations
    }
    set mySrc "#\n# ${src}.msg\n#\n";
    set myDst "#\n# ${dst}.msg\n#\n";

    set msgs 0
    set locale [::msgcat::mclocale]
    ::msgcat::mclocale $dst
    foreach myFile $files {
	set myFile [file normalize $myFile]

	# read source file
	set myFd [open $myFile r]
	set myC [read $myFd]
	close $myFd
	append mySrc "\n# $myFile\n"
	append myDst "\n# $myFile\n"

	# find namespace
	set myNs [lindex [regexp -inline -line -all -- {^namespace\s+eval\s+[[:graph:]]+\s} $myC] end]
	if {$myNs eq {}} {set myNs {namespace eval ::}}

	# put translations in namespace
	append mySrc "$myNs {\n"
	append myDst "$myNs {\n"
	set myList [list]

	# find existing translations
	foreach myMc [regexp -inline -all -- {(\[(mc|::msgcat::mc|msgcat::mc)\s.*\]){1,1}?} $myC] {
	    lappend myList [lindex [string trim $myMc {[]}] 1]
	}

	# create englich and german translation
	foreach myMc [lsort -unique $myList] {
	    if { $myMc ne "" } {
		incr msgs
		append mySrc "::msgcat::mcset $src {$myMc}\n"
		{*}$myNs "set ::my \[[list ::msgcat::mc $myMc]\]"
		append myDst "::msgcat::mcset $dst {$myMc} {$::my}\n"
	    }
	}
	append mySrc "}\n"
	append myDst "}\n"
    }

    # write translation files
    set fd [open $src_fname w]
    puts $fd $mySrc
    close $fd

    set fd [open $dst_fname w]
    fconfigure $fd -encoding utf-8
    puts $fd $myDst
    close $fd

    ::msgcat::mclocale $locale

    return $msgs
}



# ::translate::update -- Update translation catalogue for files
#
#       This procedure will update a number of translation catalogue
#       for a number of files and a number of languages.  Apart from
#       the directory where the target catalogue files will be sourced
#       from and finally written to, the procedure accepts the
#       following dash-led options that need to be properly spelled
#       for proper functioning:
#       -languages List of languages to generate catalogues for (default: en)
#       -ignore    List of file names to ignore (default: pkgIndex.txl)
#       -source    Language used in source (.tcl) files (default: en)
#       -files     List of file patterns that will be "glob:bed"
#
# Arguments:
#       msgdir	Directory for target catalogue files.
#       args	List of dash-led options and their values, see above.
#
# Results:
#       None.
#
# Side Effects:
#       Will (over)write catalogue file.  There will be one file per
#       language, with the extension .msg
proc ::translate::update { msgdir args } {
    variable TRANS

    array set opts [array get TRANS -*]
    array set opts $args

    set files [list]
    set fnames [list]
    foreach ptn $opts(-files) {
	foreach fname [glob -nocomplain $ptn] {
	    set tail [file tail $fname]
	    set match 0
	    foreach i $opts(-ignore) {
		if { [string match $i $tail] } {
		    set match 1
		    puts "Ignoring $tail for translation"
		    break
		}
	    }
	    if { ! $match } {
		lappend files $fname
		lappend fnames $tail
	    }
	}
    }

    foreach lang $opts(-languages) {
	if { $lang ne $opts(-source) } {
	    puts "Translating to $lang: $fnames"
	    __translate $msgdir $opts(-source) $lang $files
	}
    }
}


package provide translate 0.1