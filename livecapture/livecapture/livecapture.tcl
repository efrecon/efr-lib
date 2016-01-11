# livecapture.tcl -- Live capture of Windows
#
#	Library to continuously capture the content of windows on
#	Windows XP into Tk images.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.4
package require Tk
package require img::ppm
package require Ffidl
package require logger

namespace eval ::livecapture {
    variable LC
    if { ! [info exists LC] } {
	array set LC {
	    loglevel        warn
	    idgene          0
	    -poll           500
	    -contentonly    on
	    -offsetleft     0
	    -offsettop      0
	    -offsetright    0
	    -offsetbottom   0
	    -blackthreshold 0.10
	    -force          off
	    -forceclean     5
	    CAPTURE_WINDOW  0
	    CAPTURE_CLIENT  1
	    CAPTURE_RECT    2
	    CAPTURE_REVERSE 4
	    wins            ""
	    force_rebuild   {-contentonly -blackthreshold -forceclean -offsetleft -offsettop -offsetright -offsetbottom}
	}
	variable log [::logger::init [string trimleft [namespace current] ::]]
	variable libdir [file dirname [file normalize [info script]]]
	${log}::setlevel $LC(loglevel)
    }
    namespace export new loglevel config defaults capture
}


# ::livecapture::loglevel -- Set/Get current log level.
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
proc ::livecapture::loglevel { { loglvl "" } } {
    variable LC
    variable log

    if { $loglvl != "" } {
	if { [catch "${log}::setlevel $loglvl"] == 0 } {
	    set LC(loglevel) $loglvl
	}
    }

    return $LC(loglevel)
}


# ::livecapture::__trigger -- Trigger necessary callbacks
#
#	This command relays events and actions that occur on live
#	captures.  Basically, it calls back all matching callbacks,
#	which implements some sort of event model.
#
# Arguments:
#	whnd	Handle of window being live captured.
#	action	Action that occurs (event!)
#	args	Further argument definition for the event.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::livecapture::__trigger { whnd action args } {
    variable LC
    variable log

    
    set varname ::livecapture::Capture_${whnd}
    upvar \#0 $varname Capture

    # Call all callbacks that have registered for matching actions.
    if { [array names Capture cbs] ne "" } {
	foreach {ptn cb} $Capture(cbs) {
	    if { [string match $ptn $action] } {
		if { [catch {eval $cb $whnd $action $args} res] } {
		    ${log}::warn \
			"Error when invoking $action callback $cb: $res"
		}
	    }
	}
    }
}


# ::livecapture::monitor -- Event monitoring system
#
#	This command will arrange for a callback every time an event
#	which name matches the pattern passed as a parameter occurs
#	within a live capture.  The callback will be called with the
#	identifier of the window, followed by the name of the event
#	and followed by a number of additional arguments which are
#	event dependent.
#
# Arguments:
#	id	Handle of window being captured
#	ptn	String match pattern for event name
#	cb	Command to callback every time a matching event occurs.
#
# Results:
#	Return 1 on success, 0 on failure.
#
# Side Effects:
#	None.
proc ::livecapture::monitor { whnd ptn cb } {
    variable LC
    variable log

    set whnd [__gethandle $whnd]
    if { $whnd eq "" } {
	${log}::warn "'$whnd' is not a valid handle"
	return 0
    }

    set idx [lsearch $LC(wins) $whnd]
    if { $idx < 0 } {
	${log}::warn "Window '$whnd' is not monitored!"
	return 0
    }
    
    set varname ::livecapture::Capture_${whnd}
    upvar \#0 $varname Capture

    ${log}::debug "Added <$ptn,$cb> monitor on $whnd"
    lappend Capture(cbs) $ptn $cb

    return 1
}


# ::livecapture::capture -- Perform a window capture
#
#	This procedure performs a window capture and (possibly)
#	updates its associated image.
#
# Arguments:
#	whnd	Handle of monitored window (or name of Tk window).
#	force	Force update of image, independantly of nb black pixels.
#
# Results:
#	1 on success, capture and update, 0 otherwise.
#
# Side Effects:
#	None.
proc ::livecapture::capture { whnd { force 0 } } {
    variable LC
    variable log

    set whnd [__gethandle $whnd]
    if { $whnd eq "" } {
	${log}::warn "'$whnd' is not a valid handle"
	return 0
    }

    set idx [lsearch $LC(wins) $whnd]
    if { $idx < 0 } {
	${log}::warn "Window '$whnd' is not monitored!"
	return 0
    }
    
    set varname ::livecapture::Capture_${whnd}
    upvar \#0 $varname Capture

    ${log}::debug "Capturing content of '$whnd'"
    if { [string is true $force] } {
	L_CaptureClear $whnd
    }
    if { ! [L_CaptureSnap $whnd] } {
	${log}::warn "Could not capture window: [L_CaptureGetLastError $whnd]"
	return 0
    }
    foreach {w h b s} [L_CaptureGetInfo $whnd] {}
    __trigger $whnd Capture

    set updated 0
    if { [lsearch [image names] $Capture(img)] } {
	# No image yet, create one and fill it in with what we have
	image create photo $Capture(img) -data [L_CaptureGetPPM $whnd]
	set updated 1
    } else {
	# We have an image, if the signature of the captured image is
	# different than last time (or it we force it), update the
	# image.  Otherwise, do nothing, since this is an expensive
	# operation.
	if { $s != $Capture(signature) || $force } {
	    $Capture(img) put [L_CaptureGetPPM $whnd]
	    set updated 1
	} else {
	    ${log}::debug "Skipping image update, probably nothing changed"
	}
    }

    # Store latest capture values so that we can compare at next pass.
    set Capture(nbBlack) $b
    set Capture(signature) $s

    if { $updated } {
	__trigger $whnd Updated
    }
    if { $w != $Capture(width) || $h != $Capture(height) } {
	set Capture(width) $w
	set Capture(height) $h
	__trigger $whnd Resize $w $h
    }

    return $updated
}


# ::livecapture::__capture -- Regularily capture a window.
#
#	Do a capture and update the associated image if necessary.
#
# Arguments:
#	whnd	Decimal window handle.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::livecapture::__capture { whnd } {
    variable LC
    variable log

    set idx [lsearch $LC(wins) $whnd]
    if { $idx < 0 } {
	${log}::warn "Window '$whnd' is not monitored!"
	return
    }

    set varname ::livecapture::Capture_${whnd}
    upvar \#0 $varname Capture

    if { $Capture(-poll) > 0 } {
	capture $whnd $Capture(-force)
	set Capture(pollid) \
	    [after $Capture(-poll) ::livecapture::__capture $whnd]
    } else {
	set Capture(pollid) ""
    }
}


# ::livecapture::__gethandle -- Get to decimal handle
#
#	This command intelligently converts allowed input strings for
#	window handle to their decimal (integer) value.  Raw integers,
#	hexadecimal will be converted as expected.  Any other string
#	will be tested against the current set of Tk windows and will
#	be resolved to their handle if they exist.
#
# Arguments:
#	whnd	Handle of window or name of Tk window.
#
# Results:
#	The decimal integer for the window handle, or an empty string
#	if the input string could not be understood to anything valid.
#
# Side Effects:
#	None.
proc ::livecapture::__gethandle { whnd } {
    variable LC
    variable log

    if { [string is integer $whnd] } {
	return $whnd
    }

    if { [regexp {^([0-9a-fA-F])+$} $whnd] } {
	return [expr 0x$whnd]
    }
    if { [regexp {^0x([0-9a-fA-F])+$} $whnd] } {
	return [expr $whnd]
    }

    if { [winfo exists $whnd] } {
	return [expr [winfo id $whnd]]
    }

    ${log}::warn "Cannot recognise '$whnd' as a handle or a Tk window!"
    return ""
}


# ::livecapture::get -- Get live capture properties
#
#	This procedure returns some semi-internal capturing properties
#	to other modules.  The properties that are recognised are
#	handle (or win) (the low-level handle of the window), black
#	(the last number of black pixels in image), width and height
#	(the size of the image), image (or img) the image for the
#	capturing, or any other option of the capturing (all starting
#	with a dash (-)).
#
# Arguments:
#	whnd	Handle of monitored window (or name of Tk window)
#	type	Property to get
#
# Results:
#	The value of the property
#
# Side Effects:
#	None.
proc ::livecapture::get { whnd type } {
    variable LC
    variable log

    set whnd [__gethandle $whnd]
    if { $whnd eq "" } {
	${log}::warn "'$whnd' is not a valid handle"
	return ""
    }

    set varname ::livecapture::Capture_${whnd}
    upvar \#0 $varname Capture

    switch -glob -- $type {
	"handle" -
	"whnd" -
	"window" -
	"win" {
	    return $Capture(win)
	}
	"black" {
	    return $Capture(nbBlack)
	}
	"signature" {
	    return $Capture(signature)
	}
	"width" -
	"height" {
	    return $Capture($type)
	}
	"image" -
	"img" {
	    return $Capture(img)
	}
	"-*" {
	    return [config $whnd $type]
	}
    }

    return ""
}


# ::livecapture::new -- Start monitoring a window
#
#	Start monitoring a window and see to copy its content into an
#	image.
#
# Arguments:
#	whnd	Handle of the window to watch (or name of Tk window).
#	(img)	Name of image to use for bitmap content storage.
#	args	List of key values for configuration (see config)
#
# Results:
#	Returns the image that will represent the capture in memory
#
# Side Effects:
#	Will suck your CPU, granted!
proc ::livecapture::new { whnd args } {
    variable LC
    variable log

    set whnd [__gethandle $whnd]
    if { $whnd eq "" } {
	${log}::warn "'$whnd' is not a valid handle"
	return ""
    }

    set varname ::livecapture::Capture_${whnd}
    upvar \#0 $varname Capture

    set idx [lsearch $LC(wins) $whnd]
    if { $idx < 0 } {
	set Capture(win) $whnd
	set Capture(nbBlack) -1
	set Capture(signature) -1
	set Capture(pollid) ""
	set Capture(cbs) [list]
	set Capture(width) 0
	set Capture(height) 0
	lappend LC(wins) $Capture(win)

	if { [string match "-*" [lindex $args 0]] || [llength $args] == 0 } {
	    set img ::livecapture::image_[incr LC(idgene)]
	} else {
	    set img [lindex $args 0]
	    set args [lrange $args 1 end]
	}

	set Capture(img) $img
	foreach opt [array names LC "-*"] {
	    set Capture($opt) $LC($opt)
	}
	eval config $whnd $args
	${log}::debug "Created new live window capturing on '$whnd'"
    } else {
	if { [string match "-*" [lindex $args 0]] || [llength $args] == 0 } {
	} else {
	    set Capture(img) [lindex $args 0]
	    set args [lrange $args 1 end]
	}
	eval config $whnd $args
    }

    return $Capture(img)
}


# ::livecapture::delete -- Delete a live capture
#
#	Delete a live capture and all references to it.
#
# Arguments:
#	whnd	Handle of window being captured.
#
# Results:
#	Returns a positive number on success, 0 otherwise.
#
# Side Effects:
#	None.
proc ::livecapture::delete { whnd } {
    variable LC
    variable log

    set whnd [__gethandle $whnd]
    if { $whnd eq "" } {
	${log}::warn "'$whnd' is not a valid handle"
	return 0
    }

    set idx [lsearch $LC(wins) $whnd]
    if { $idx < 0 } {
	${log}::warn "Window '$whnd' is not monitored!"
	return 0
    }
    
    set varname ::livecapture::Capture_${whnd}
    upvar \#0 $varname Capture

    set res 1
    if { [L_CaptureExists $whnd] } {
	set res [L_CaptureDelete $whnd]
    }
    unset Capture
    set LC(wins) [lreplace $LC(wins) $idx $idx]

    return $res
}


# ::livecapture::config -- Configure a live capture
#
#	This command set or get the options of a given live capture
#	that has previously been created by the ::livecapture::new
#	command.
#
# Arguments:
#	whnd	Handle of monitored window (or name of Tk window).
#	args	List of options
#
# Results:
#	Return all options, the value of the option requested or set
#	the options passed as a parameter.
#
# Side Effects:
#	None.
proc ::livecapture::config { whnd args } {
    variable LC
    variable log

    set whnd [__gethandle $whnd]
    if { $whnd eq "" } {
	${log}::warn "'$whnd' is not a valid handle"
	return ""
    }
    
    # Check that this is one of our connections
    set idx [lsearch $LC(wins) $whnd]
    if { $idx < 0 } {
	${log}::warn "Handle of an unmonitored window '$whnd'"
	return -code error "Identifier invalid"
    }

    set varname ::livecapture::Capture_${whnd}
    upvar \#0 $varname Capture

    set o [lsort [array names Capture "-*"]]

    set result ""
    set rebuild 0
    if { [llength $args] == 0 } {      ;# Return all results
	foreach name $o {
	    lappend result $name $Capture($name)
	}
    } else {
	foreach {opt value} $args {        ;# Get one or set some
	    if { [lsearch $o $opt] == -1 } {
		return -code error \
		    "Unknown option $opt, must be: [join $o ", " ]"
	    }
	    if { [llength $args] == 1 } {  ;# Get one config value
		set result $Capture($opt)
		break
	    }
	    set Capture($opt) $value          ;# Set the config value
	    if { [lsearch $LC(force_rebuild) $opt] >= 0 } {
		set rebuild 1
	    }
	}
    }

    set start_capturing 1
    
    if { $Capture(pollid) ne "" } {
	after cancel $Capture(pollid)
	set Capture(pollid) ""
    }

    if { $rebuild || ! [L_CaptureExists $whnd] } {
	if { [L_CaptureExists $whnd] } {
	    L_CaptureDelete $whnd
	}
	set getStyle $LC(CAPTURE_REVERSE)
	if { [string is true $Capture(-contentonly)] } {
	    incr getStyle $LC(CAPTURE_CLIENT)
	}
	if { $Capture(-offsetleft) != 0 \
		 || $Capture(-offsettop) != 0 \
		 || $Capture(-offsetright) != 0 \
		 || $Capture(-offsetbottom) != 0} {
	    incr getStyle $LC(CAPTURE_RECT)
	}
	set success [L_CaptureNew $whnd $getStyle \
			 $Capture(-blackthreshold) $Capture(-forceclean)]
	if { !$success } {
	    ${log}::warn "Could not start capturing $whnd!"
	    set start_capturing 0
	}

    }

    if { $start_capturing } {
	L_CaptureSetRect $whnd \
	    $Capture(-offsetleft) $Capture(-offsettop) \
	    $Capture(-offsetright) $Capture(-offsetbottom)
	__capture $whnd
    }


    return $result
}



# ::livecapture::defaults -- Set/Get defaults for all new live captures.
#
#	This command sets or gets the defaults options for all new
#	live captures, it will not perpetrate on existing captures use
#	::livecapture::config instead.
#
# Arguments:
#	args	List of -key value or just -key to get value
#
# Results:
#	Return all options, the option requested or set the options
#
# Side Effects:
#	None.
proc ::livecapture::defaults { args } {
    variable LC
    variable log

    set o [lsort [array names LC "-*"]]

    if { [llength $args] == 0 } {      ;# Return all results
	set result ""
	foreach name $o {
	    lappend result $name $LC($name)
	}
	return $result
    }

    foreach {opt value} $args {        ;# Get one or set some
	if { [lsearch $o $opt] == -1 } {
	    return -code error "Unknown option $opt, must be: [join $o ,]"
	}
	if { [llength $args] == 1 } {  ;# Get one config value
	    return $LC($opt)
	}
	set LC($opt) $value           ;# Set the config value
    }
}


# ::livecapture::L_CaptureGetInfo -- Get Info from last capture
#
#	This command is a wrapper around the CaptureGetInfo function
#	from the DLL, it performs appropriate translation between
#	Tcl-string-alike world and binary arguments.
#
# Arguments:
#	whnd	Handle of window
#
# Results:
#	Returns a list composed of the width, height and number of
#	black pixels in the last capture.
#
# Side Effects:
#	None.
proc ::livecapture::L_CaptureGetInfo { whnd } {
    set w [binary format i 0]
    set h [binary format i 0]
    set b [binary format i 0]
    set s [binary format i 0]
    __L_CaptureGetInfo $whnd w h b s
    binary scan $w i width
    binary scan $h i height
    binary scan $b i nbBlack
    binary scan $s i signature

    return [list $width $height $nbBlack $signature]
}


# ::livecapture::L_CaptureGetData -- Get pixel data from last capture
#
#	This command is a wrapper around the CaptureGetData function
#	from the DLL, it performs appropriate translation between
#	Tcl-string-alike world and binary arguments.
#
# Arguments:
#	whnd	Handle of window
#
# Results:
#	Returns the raw pixel content of the last capture.
#
# Side Effects:
#	None.
proc ::livecapture::L_CaptureGetData { whnd } {
    foreach { w h b s } [L_CaptureGetInfo $whnd] {}
    set size [expr $w * $h * 3]
    set buf [binary format x$size]
    __L_CaptureGetData $whnd buf
    return $buf
}


# ::livecapture::L_CaptureGetPPM -- Get pixel data from last capture
#
#	This command is a wrapper around the CaptureGetPPM function
#	from the DLL, it performs appropriate translation between
#	Tcl-string-alike world and binary arguments.
#
# Arguments:
#	whnd	Handle of window
#
# Results:
#	Returns the PPM coded pixel content of the last capture.
#
# Side Effects:
#	None.
proc ::livecapture::L_CaptureGetPPM { whnd } {
    foreach { w h b s } [L_CaptureGetInfo $whnd] {}
    set size [expr $w * $h * 3]
    incr size 64
    set buf [binary format x$size]
    __L_CaptureGetPPM $whnd buf
    return $buf
}


# ::livecapture::__init -- Initialise module
#
#	This procedure sees to install library access points to the
#	DLL that will perform most of the underlying job.
#
# Arguments:
#	none
#
# Results:
#	Boolean describing success or failure
#
# Side Effects:
#	None.
proc ::livecapture::__init {} {
    variable log
    variable libdir
    global auto_path

    set lkupdirs [list $libdir \
		      [file join $libdir .. capture]]
    set lkupdirs [concat $lkupdirs $auto_path]

    ${log}::debug "Looking for capture.dll in $lkupdirs"
    foreach d $lkupdirs {
	set dll [file join $d capture.dll]
	if { [file exists $dll] } {
	    if { [catch {::ffidl::symbol $dll CaptureNew} a] } {
		${log}::notice "Cannot access symbols in $dll, skipping"
		set dll ""
	    } else {
		break
	    }
	} else {
	    set dll ""
	}
    }
    if { $dll eq "" } {
	${log}::critical "Could not find capturing dll, will not function"
	return
    }
    ${log}::info "Using '$dll' for capturing implementation."

    # Install all functions exported from the library as entry points
    # in this namespace, prefixed with L_. Functions that need a
    # wrapper are imported with a leading __
    if { $dll ne "" } {
	set a [::ffidl::symbol $dll CaptureNew]
	::ffidl::callout ::livecapture::L_CaptureNew {int int float int} \
	    int $a

	set a [::ffidl::symbol $dll CaptureSnap]
	::ffidl::callout ::livecapture::L_CaptureSnap {int} int $a
	
	set a [::ffidl::symbol $dll CaptureSetRect]
	::ffidl::callout ::livecapture::L_CaptureSetRect {int int int int int}\
	    int $a
	
	set a [::ffidl::symbol $dll CaptureExists]
	::ffidl::callout ::livecapture::L_CaptureExists {int} int $a
	
	set a [::ffidl::symbol $dll CaptureClear]
	::ffidl::callout ::livecapture::L_CaptureClear {int} int $a

	set a [::ffidl::symbol $dll CaptureDelete]
	::ffidl::callout ::livecapture::L_CaptureDelete {int} int $a
	
	set a [::ffidl::symbol $dll CaptureGetInfo]
	::ffidl::callout ::livecapture::__L_CaptureGetInfo \
	    {int pointer-var pointer-var pointer-var pointer-var} int $a

	set a [::ffidl::symbol $dll CaptureGetData]
	::ffidl::callout ::livecapture::__L_CaptureGetData \
	    {int pointer-var} int $a

	set a [::ffidl::symbol $dll CaptureGetPPM]
	::ffidl::callout ::livecapture::__L_CaptureGetPPM \
	    {int pointer-var} int $a

	set a [::ffidl::symbol $dll CaptureGetLastError]
	::ffidl::callout ::livecapture::L_CaptureGetLastError \
	    {int} pointer-utf8 $a
    }
}


# Now automatically initialises this module, once and only once
# through calling the __init procedure that was just declared above.
namespace eval ::livecapture {
    variable inited
    if { ! [info exists inited] } {
	set inited [::livecapture::__init]
    }
}

package provide livecapture 0.1
