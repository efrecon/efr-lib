# splash.tcl -- Splash window creation
#
#	Library to open splash windows to make user wait until the
#	program has initialised.  The library solely makes use of Tk
#	base widgets and is not dependent on any other package so as
#	to be able to be loaded from the very beginning of an
#	application.
#
# Copyright (c) 2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.4
package require Tk


namespace eval ::splash {
    variable SPLASH
    if { ! [info exists SPLASH] } {
	array set SPLASH {
	    -delay             0
	    -progress          -1
	    -text              off
	    -imgfile           ""
	    -anchor            c
	    -hidemain          on
	    -hideall           off
	    -autoraise         on
	    -topmost           on
	    -alpha             1.0
	    idgene             0
	    prefix             splash
	    wins               ""
	    swallow            ""
	    toplevels          ""
	    renamed            0
	}
	variable libdir [file dirname [file normalize [info script]]]
    }
    namespace export new redraw config defaults
}


# ::splash::new -- Create a new splash window
#
#	This command will create a new splash on the screen.  This
#	command takes a number of options and arguments that control
#	the appearance and behaviour of the splash window.  -delay is
#	the number of milliseconds after which the splash window will
#	automatically disappear, if set to less or equal than zero,
#	you will have to remove the splash window yourself.  -progress
#	indicates that the splash window will be mounted by a progress
#	bar, conisdering that it will have to perform a finite number
#	of operations, the argument to -progress.  -text controls
#	whether the splash will also have a text information bar or
#	not (boolean). -imgfile points to an image that will
#	automatically be loaded and shown in the splash screen, using
#	built-in photo types is here a good idea, otherwise, you will
#	have to load the Img package by yourself prior to calling the
#	splash.  -anchor specifies the position of the splash window
#	of the screen, it defaults to "c", -hidemain is a boolean that
#	tells wether the splash window should automatically hide the
#	main (.) window and make it automatically appear once
#	destroyed.  -autoraise is a boolean which can force the window
#	to raise on top of all other windows every time the
#	initialisiation progresses.
#
# Arguments:
#	args	list of options, see above
#
# Results:
#	Return the name of a main Tk toplevel pointing at the splash
#	window, this argument should be used in all further calls to
#	this library.
#
# Side Effects:
#	Create a new toplevel, possibly hides the main toplevel.
proc ::splash::new { args } {
    variable SPLASH

    # Choose a new inexisting toplevel name for the splash
    for {set wname .$SPLASH(prefix)$SPLASH(idgene)} {[winfo exists $wname]} \
	{ incr SPLASH(idgene) } {}
    
    lappend SPLASH(wins) $wname

    set varname ::splash::$wname
    upvar \#0 $varname Splash

    set Splash(name) $wname
    set Splash(imgfile) ""
    set Splash(img) ""
    set Splash(destruction) ""
    set Splash(progress) 0

    # Copy default options
    foreach opt [array names SPLASH "-*"] {
	set Splash($opt) $SPLASH($opt)
    }

    # Do configuration
    eval config $wname $args

    return $wname
}


# ::splash::redraw -- (re)draw a splash window
#
#	This command will create or a update a splash window to
#	accomodate its present options and arguments.  It is typically
#	called every time the splash is configured or created, but can
#	be called at any time for screen refresh.
#
# Arguments:
#	wname	Splash window as created by ::splash::new
#
# Results:
#	None.
#
# Side Effects:
#	Create a new toplevel, possibly hides the main toplevel.
proc ::splash::redraw { wname } {
    variable SPLASH
    global tcl_platform

    # Check it is ours
    set idx [lsearch $SPLASH(wins) $wname]
    if { $idx < 0 } {
	return -code error "Window identifier $wname is not a splash window!"
    }

    set varname ::splash::$wname
    upvar \#0 $varname Splash

    # Load in image file for the splash screen if necessary, rm_img
    # will contain an (old) image to unload from memory if necessary.
    # Unloading is done at the end of this procedure to ensure the
    # (old) image is not shown anymore.
    set rm_img ""
    if { $Splash(imgfile) ne $Splash(-imgfile) } {
	set rm_img $Splash(img)
	if { [catch {image create photo -file $Splash(-imgfile)} img] } {
	    return -code error \
		"Could not load splash photo $Splash(-imgfile): $img"
	}
	set Splash(img) $img
	set Splash(imgfile) $Splash(-imgfile)
    }

    # Create/update main splash window with label for image
    if { [winfo exists $wname] } {
	${wname}.img configure -image $Splash(img)
    } else {
	if { [string is true $Splash(-hidemain)] } {
	    wm withdraw .
	}
	::toplevel $wname
	wm overrideredirect $wname on

	label ${wname}.img -border 1 -image $Splash(img)
	pack ${wname}.img
    }
    
    # Fix transparency if necessary and possible
    if { $Splash(-alpha) < 1.0 } {
	catch "wm attributes $wname -alpha $Splash(-alpha)"
    }

    # Create/remove text field
    if { [string is true $Splash(-text)] && ! [winfo exists ${wname}.txt] } {
	set Splash(infomsg) "Initialising..."
	label ${wname}.txt -textvariable ${varname}(infomsg)
	pack ${wname}.txt -side bottom -after ${wname}.img -fill x
    }
    if { [string is false $Splash(-text)] && [winfo exists ${wname}.txt] } {
	::destroy ${wname}.txt
    }

    # Create/remote progress bar.
    if { $Splash(-progress) > 0 } {
	if { ! [winfo exists ${wname}.pgess] } {
	    progressbar ${wname}.pgess -from 0 \
		-to $Splash(-progress) -length [image width $Splash(img)]
	    pack ${wname}.pgess -side bottom -after ${wname}.img -expand on \
		-fill x
	} else {
	    ${wname}.pgess configure -from 0 -to $Splash(-progress)
	}
    }
    if { $Splash(-progress) <= 0 && [winfo exists ${wname}.pgess] } {
	::destroy ${wname}.pgess
    }
    
    # Position window on screen
    update idletasks
    set width [winfo width $wname]
    set height [winfo height $wname]
    set wscreen [winfo screenwidth $wname]
    set hscreen [winfo screenheight $wname]
    switch $Splash(-anchor) {
	"nw" {
	    set x 0
	    set y 0
	    wm geometry $wname +$x+$y
	}
	"n" {
	    set x [expr {($wscreen - $width) / 2}]
	    set y 0
	    wm geometry $wname +$x+$y
	}
	"ne" {
	    set x [expr {$wscreen - $width}]
	    set y 0
	    wm geometry $wname +$x+$y
	}
	"e" {
	    set x [expr {$wscreen - $width}]
	    set y [expr {($hscreen - $height) / 2}]
	    wm geometry $wname +$x+$y
	}
	"se" {
	    set x [expr {$wscreen - $width}]
	    set y [expr {$hscreen - $height}]
	    wm geometry $wname +$x+$y
	}
	"s" {
	    set x [expr {($wscreen - $width) / 2}]
	    set y [expr {$hscreen - $height}]
	    wm geometry $wname +$x+$y
	}
	"sw" {
	    set x 0
	    set y [expr {$hscreen - $height}]
	    wm geometry $wname +$x+$y
	}
	"w" {
	    set x 0
	    set y [expr {($hscreen - $height) / 2}]
	    wm geometry $wname +$x+$y
	}
	"c" -
	default {
	    set x [expr {($wscreen - $width) / 2}]
	    set y [expr {($hscreen - $height) / 2}]
	    wm geometry $wname +$x+$y
	}
    }

    # Be sure the geometry setting has taken effect
    update idletasks

    # Arrange for own procedure to be called on destruction of the splash
    wm protocol ${wname} WM_DELETE_WINDOW "::splash::destroy $wname"
    bind ${wname} <Destroy> "::splash::destroy $wname"

    # Raise the splash and make sure it is shown.
    wm deiconify $wname
    raise ${wname}
    update
    if { $tcl_platform(platform) eq "windows" } {
	wm attributes $wname -topmost $Splash(-topmost)
    }

    if { $Splash(destruction) ne "" } {
	after cancel $Splash(destruction)
	set Splash(destruction) ""
    }

    if { $Splash(-delay) > 0 } {
	after $Splash(-delay) "::splash::destroy $wname"
    }

    # Remove unecessary image from memory if we have changed image in
    # the splash
    if { $rm_img ne "" } {
	image delete $rm_img
    }
}


# ::splash::progress -- Modify progress in a splash window
#
#	This command will modify the progress level of a given splash
#	window and update both the progress bar and text if possible
#	and necessary.
#
# Arguments:
#	wname	Name of splash window, as returned by ::splash::new
#	txt	Text to show in the text bar, if such is configured
#	pgs_n	Increment for next level of progress, if applicable.
#
# Results:
#	Return a list of operations that were performed on the removed
#	splash, these can be any combination of TEXT, PROGRESS and
#	RAISE
#
# Side Effects:
#	Will modify the appearance of the splash window.
proc ::splash::progress { wname {txt ""} {pgs_n 1}} {
    variable SPLASH

    # Check it is ours
    set idx [lsearch $SPLASH(wins) $wname]
    if { $idx < 0 } {
	return -code error "Window identifier $wname is not a splash window!"
    }

    set varname ::splash::$wname
    upvar \#0 $varname Splash

    set res [list]

    if { [string is true $Splash(-hideall)] } {
	foreach t $SPLASH(toplevels) {
	    wm withdraw $t
	}
    }

    if { [string is true $Splash(-text)] && [winfo exists ${wname}.txt] } {
	set Splash(infomsg) $txt
	lappend res "TEXT"
    }

    if { $Splash(-progress) >= 0 } {
	incr Splash(progress) $pgs_n
	progressbar:set ${wname}.pgess $Splash(progress)
	lappend res "PROGRESS"
    }

    if { [string is true $Splash(-autoraise)] } {
	raise $wname
	update
	lappend res "RAISE"
    }

    return $res
}


# ::splash::destroy -- destroy a splash window
#
#	This command will destroy any existing splash window and all
#	its currently associated context.
#
# Arguments:
#	wname	Name of splash window, as returned by ::splash::new
#
# Results:
#	Return a list of operations that were performed on the removed
#	splash, these can be any combination of WINDOW, VARIABLE and
#	UNREGISTER.
#
# Side Effects:
#	Will destroy the splash, if present, and possibly restore the
#	main window (.)
proc ::splash::destroy { wname } {
    global tcl_platform
    variable SPLASH

    set res [list]

    if { [winfo exists $wname] } {
	::destroy $wname
	lappend res "WINDOW"
    }

    if { [info exists ::splash::$wname] } {
	set varname ::splash::$wname
	upvar \#0 $varname Splash
	
	if { [array names Splash img] ne "" && $Splash(img) ne "" } {
	    image delete $Splash(img)
	}
	if { [array names Splash -hidemain] ne "" \
		 && [string is true $Splash(-hidemain)] } {
	    wm deiconify .
	    if { $tcl_platform(platform) eq "windows" } {
		if { [string is false [wm attributes . -topmost]] } {
		    wm attributes . -topmost on
		    wm attributes . -topmost off
		}
	    }
	}
	if { [array names Splash -hideall] ne "" \
		 && [string is true $Splash(-hideall)] } {
	    foreach t $SPLASH(toplevels) {
		wm deiconify $t
		if { $tcl_platform(platform) eq "windows" } {
		    if { [string is false [wm attributes $t -topmost]] } {
			wm attributes $t -topmost on
			wm attributes $t -topmost off
		    }
		}
	    }
	    set SPLASH(toplevels) ""
	    set idx [lsearch $SPLASH(swallow) $wname]
	    if { $idx >= 0 } {
		set SPLASH(swallow) [lreplace $SPLASH(swallow) $idx $idx]
	    }
	    if { [llength $SPLASH(swallow)] <= 0 } {
		rename ::toplevel ""
		rename ::splash::__toplevel ::toplevel
		set SPLASH(renamed) 0
	    }
	}
	unset Splash
	lappend res "VARIABLE"
    }

    set idx [lsearch $SPLASH(wins) $wname]
    if { $idx >= 0 } {
	set SPLASH(wins) [lreplace $SPLASH(wins) $idx $idx]
	lappend res "UNREGISTER"
    }

    return $res
}


# ::splash::config -- (re)configure a splash window
#
#	This command will modify or get the configuration of a splash
#	window that has been created by the ::splash::new command.
#	Any option can be modified.
#
# Arguments:
#	wname	Name of splash window, as returned by ::splash::new
#	args	list of options or options and their arguments
#
# Results:
#	Return all options, the value of the option requested or set
#	the options passed as a parameter.
#
# Side Effects:
#	None
proc ::splash::config { wname args } {
    variable SPLASH

    # Check it is ours
    set idx [lsearch $SPLASH(wins) $wname]
    if { $idx < 0 } {
	return -code error "Window identifier $wname is not a splash window!"
    }

    set varname ::splash::$wname
    upvar \#0 $varname Splash

    set o [lsort [array names Splash "-*"]]

    set result ""
    if { [llength $args] == 0 } {      ;# Return all results
	foreach name $o {
	    lappend result $name $Splash($name)
	}
    } else {
	foreach {opt value} $args {        ;# Get one or set some
	    if { [lsearch $o $opt] == -1 } {
		return -code error \
		    "Unknown option $opt, must be: [join $o ", " ]"
	    }
	    if { [llength $args] == 1 } {  ;# Get one config value
		set result $Splash($opt)
		break
	    }
	    set Splash($opt) $value          ;# Set the config value
	}
    }

    if { [string is true $Splash(-hideall)] } {
	lappend SPLASH(swallow) $wname

	if { ! $SPLASH(renamed) } {
	    rename ::toplevel ::splash::__toplevel
	    proc ::toplevel { name args } {
		set t [eval ::splash::__toplevel $name $args]
		set idx [lsearch -exact $::splash::SPLASH(wins) $name]
		if { $idx < 0 } {
		    after idle wm withdraw $t
		    lappend ::splash::SPLASH(toplevels) $t
		}
		return $t
	    }
	    set SPLASH(renamed) 1
	}
    }

    redraw $wname
    
    return $result
}


# ::splash::defaults -- Set/Get defaults for all new splash windows.
#
#	This command sets or gets the defaults options for all new
#	splash windows, it will not perpetrate on existing splash use
#	::splash::config instead.
#
# Arguments:
#	args	List of -key value or just -key to get value
#
# Results:
#	Return all options, the option requested or set the options
#
# Side Effects:
#	None.
proc ::splash::defaults { args } {
    variable SPLASH
    variable log

    set o [lsort [array names SPLASH "-*"]]

    if { [llength $args] == 0 } {      ;# Return all results
	set result ""
	foreach name $o {
	    lappend result $name $SPLASH($name)
	}
	return $result
    }

    foreach {opt value} $args {        ;# Get one or set some
	if { [lsearch $o $opt] == -1 } {
	    return -code error "Unknown option $opt, must be: [join $o ,]"
	}
	if { [llength $args] == 1 } {  ;# Get one config value
	    return $SPLASH($opt)
	}
	set SPLASH($opt) $value           ;# Set the config value
    }
}


# ::splash::progressbar -- Poor's Man Progress Bar
#
#	Create a cheap progress bar via a scale.  This is adapted from
#	the wiki code at http://wiki.tcl.tk/9621
#
# Arguments:
#	W	Path to Tk widget
#	args	key value options to the pseudo-widget
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::splash::progressbar {W args} {
    array set map [list \
		       -bd -borderwidth \
		       -bg -background \
		      ]

    array set arg [list \
		       -activebackground blue \
		       -borderwidth 1 \
		       -from 0 \
		       -to 100 \
		       -orient horizontal \
		       -sliderrelief flat \
		       -sliderlength 0 \
		       -troughcolor #AAAAAA \
		       -showvalue 0 \
		       -state active \

		      ]

    foreach {option value} $args {
	if { [info exists map($option)] } { set option $map($option) }
	set arg($option) $value
    }
    set arg(-resolution) [expr -$arg(-from)]

    eval [linsert [array get arg] 0 scale $W]

    bind $W <Enter>  {break}
    bind $W <Leave>  {break}
    bind $W <Motion> {break}
    bind $W <1>      {break}
    bind $W <ButtonRelease-1> {break}

    bind $W <Configure> [list [namespace current]::progressbar:redraw %W]

    return $W
}


# ::splash::progressbar:redraw -- Redraw Poor's Man Progress Bar
#
#	Redraw a cheap progress bar.  This is adapted from the wiki
#	code at http://wiki.tcl.tk/9621
#
# Arguments:
#	W	Path to Tk widget
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::splash::progressbar:redraw {W} {
    set value [expr -[$W cget -resolution]]
    set bd    [$W cget -bd]
    set ht    [$W cget -highlightthickness]
    set from  [$W cget -from]
    set to    [$W cget -to]
    set w [winfo width $W]
    set tw [expr {$w - (4 * $bd) - (2 * $ht)}]
    set range [expr {$to - $from}]
    set pc [expr {($value - $from) * 1.0 / $range}]
    set sl [expr {round($pc * $tw)}]
    $W configure -sliderlength $sl
}


# ::splash::progressbar:set -- Set value of Poor's Man Progress Bar
#
#	Set the current value of a cheap progress bar.  This is
#	adapted from the wiki code at http://wiki.tcl.tk/9621
#
# Arguments:
#	W	Path to Tk widget
#	value	Value (between -from and -to)
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::splash::progressbar:set {W value} {
    $W configure -resolution [expr -$value]
    [namespace current]::progressbar:redraw $W
}



package provide splash 0.4
