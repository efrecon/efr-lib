# picbrowser.tcl -- Picture Browser
#
#	This module implements a picture browser that is aimed at
#	directories which contain a lot of pictures.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tk
package require logger
package require fileutil::magic::mimetype
package require fileutil

package require uobj
package require imgop
package require argutil

namespace eval ::picbrowser {
    # Initialise the global state
    variable PB
    if { ![info exists PB] } {
	array set PB {
	    idgene         0
	    loglevel       warn
	    browsers       ""
	    forcetclresize 0
	    dnd            0
	    -thumbsize     "64x64"
	    -root          ""
	    -files         "*.{gif,ppm,png,jpg,pbm,bmp,lnk}"
	    -spacingx      10
	    -spacingy      10
	    -font          "Helvetica 7"
	    -redrawfreq    100
	    -singlebrowse  off
	    -dnd           on
	    -home          on
	    -maxtitlechar  40
	    -title         "%nicedir%"
	}
	variable libdir [file dirname [file normalize [info script]]]
	::uobj::install_log picbrowser PB; # Creates 'log' namespace variable
	::uobj::install_defaults picbrowser PB
    }
    namespace export loglevel new defaults
}


# Be intelligent about DND support
if { [catch {package require tkdnd 2.0} ver] == 0 } {
    set ::picbrowser::PB(dndcapable) 1
}


# ::picbrowser::__readimg -- Make an icon out of a picture
#
#	This procedure updates the content of an icon made with
#	::picbrowser::__picicon so that the picture inside the icon
#	reflects the content of the picture that the icon represents.
#	In short, it resizes the picture pointed at by the file name
#	to an iconic size and visualises it in the widget.
#
# Arguments:
#	fm	Frame container for the icon.
#	fname	Full path to the picture.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::picbrowser::__readimg { fm fname } {
    variable PB
    variable log

    if { [winfo exists $fm] } {
	set top .[lindex [split $fm "."] 1]
	set varname "::picbrowser::browser_${top}"
	upvar \#0 $varname BROWSER
	
	foreach {tw th} [split $BROWSER(-thumbsize) "x"] {}
	foreach {iw ih} [::imgop::size $fname] {}
	if { $iw eq "" } {
	    ${log}::warn "Could not read size of $fname!"
	    return
	}
	set sx [expr double($tw)/double($iw)]
	set sy [expr double($th)/double($ih)]
	if { $sx < $sy } { set scale $sx } else { set scale $sy }
	if { $scale < 1.0 } {
	    set dw [expr round($iw * $scale)]
	    set dh [expr round($ih * $scale)]
	    if { [catch {::imgop::resize $fname $dw $dh} img] } {
		${log}::warn "Error when reading image at $fname: $img"
		set img ""
	    }
	} else {
	    set img [::imgop::loadimage $fname]
	}
	if { $img ne "" } {
	    if { [winfo exists $fm.ico] } {
		$fm.ico configure -image $img
		__trigger $top IconInstall $fname $fm $img
	    } else {
		image delete $img
	    }
	}
    }
}


# ::picbrowser::__select -- Select
#
#	This procedure is called when an icon is selected.  It changes
#	the visual state of the iconic representation of the
#	file/directory.
#
# Arguments:
#	top	Path to pic browser widget
#	fm	Frame container for the icon
#	fname	Full path to the picture/file/directory
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::picbrowser::__select { top fm fullpath } {
    variable PB
    variable log

    # Check that this is one of our browsers
    set idx [lsearch $PB(browsers) $top]
    if { $idx < 0 } {
	${log}::warn "Browser $top is not valid"
	return -code error "Browser identifier invalid"
    }

    set varname "::picbrowser::browser_${top}"
    upvar \#0 $varname BROWSER

    foreach w [list $fm.ico $fm.lbl] {
	if { [$w cget -state] eq "normal" } {
	    $w configure -state active
	    __trigger $top IconActivate $fullpath $fm
	} else {
	    $w configure -state normal
	    __trigger $top IconDeactivate $fullpath $fm
	}
    }
}


# ::picbrowser::__freeicon -- Destroy an icon
#
#	This procedure destroys an icon and all the resources that are
#	associated to it, i.e. the image if it is not one of the
#	standard images.
#
# Arguments:
#	top	Top picbrowser widget
#	ico	Tk path to icon to remove
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::picbrowser::__destroyicon { top ico } {
    variable PB
    variable log

    # Check that this is one of our browsers
    set idx [lsearch $PB(browsers) $top]
    if { $idx < 0 } {
	${log}::warn "Browser $top is not valid"
	return -code error "Browser identifier invalid"
    }

    set varname "::picbrowser::browser_${top}"
    upvar \#0 $varname BROWSER

    if { [winfo exists $ico] } {
	if { $PB(dndcapable) && [string is true $BROWSER(-dnd)] } {
	    foreach w [list $ico.ico $ico.lbl] {
		::tkdnd::drag_source unregister $w
	    }
	}
	set img [$ico.ico cget -image]
	set fullpath [$ico.lbl cget -text]
	__trigger $top IconDestroy $fullpath
	::destroy $ico
	if { $img ne "" \
		 && [lsearch [list $PB(ico_up) $PB(ico_folder) \
				  $PB(ico_unknown) $PB(ico_image) \
				  $PB(ico_home)] $img] < 0 } {
	    catch {image delete $img}
	}
	catch {$top.canvas delete $ico}
    }
}


# ::picbrowser::__dragsource -- Send a file/directory
#
#	This procedure is bound to created icons and will send the
#	file or directory that it represents to the drop target.
#
# Arguments:
#	top	Top picbrowser widget
#	fulpath	Path to file or directory represented by icon.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::picbrowser::__dragsource { top fullpath } {
    variable PB
    variable log

    # Check that this is one of our browsers
    set idx [lsearch $PB(browsers) $top]
    if { $idx < 0 } {
	${log}::warn "Browser $top is not valid"
	return -code error "Browser identifier invalid"
    }

    set varname "::picbrowser::browser_${top}"
    upvar \#0 $varname BROWSER

    ${log}::debug "DND sending $fullpath back"
    return [list copy DND_Files \
		[list [file nativename [file normalize $fullpath]]]]
}


# ::picbrowser::__picicon -- Create an icon for a file
#
#	This procedure creates a widget that will serve as an icon for
#	a given file or directory.  All files and directories are
#	represented by standard icons.  The icons for pictures will
#	show a thumbnail of the picture.
#
# Arguments:
#	top	Top picbrowser widget
#	fullpath	Full path to the file/directory
#
# Results:
#	Return a Tk path to a widget that represents the
#	file/directory, an empty string on errors.
#
# Side Effects:
#	Will actively trigger the creation of thumbnails.
proc ::picbrowser::__picicon { top fullpath {sizeestimate_p ""}} {
    variable PB
    variable log
    variable libdir
    global tcl_platform
    
    set varname "::picbrowser::browser_${top}"
    upvar \#0 $varname BROWSER

    # If the standard icons for file and directory representations
    # have not yet been created, read these from the library path,
    # scaling them to the thumbnail size.
    foreach {tw th} [split $BROWSER(-thumbsize) "x"] {}
    if { [array names PB "ico*"] eq "" } {
	${log}::notice "Reading standard icons for file and dir representations"
	foreach name [list folder image unknown up home] {
	    set icopath [file join $libdir icons "${name}.png"]
	    ${log}::debug "Resizing $icopath..."
	    if { $PB(forcetclresize) } {
		set tmpimg [::imgop::loadimage $icopath]
		if { $tmpimg eq "" } {
		    ${log}::warn "Could not load icon at $icopath, danger ahead"
		} else {
		    set PB(ico_${name}) [::imgop::imgresize $tmpimg $tw -1 \
					     "::picbrowser::ico_${name}"]
		}
	    } else {
		set PB(ico_${name}) [::imgop::resize $icopath $tw -1]
		if { $PB(ico_${name}) eq "" } {
		    ${log}::warn "Could not load icon as PNG, trying GIF\
                                  instead"
		    set icopath [file join $libdir icons "${name}.gif"]
		    set tmpimg [::imgop::loadimage $icopath]
		    if { $tmpimg eq "" } {
			${log}::warn "Could not load icon at $icopath,\
                                      danger ahead"
		    } else {
			set PB(ico_${name}) [::imgop::imgresize $tmpimg $tw -1 \
						 "::picbrowser::ico_${name}"]
			::imgop::transparent $PB(ico_${name})
		    }
		}
	    }
	}
    }

    # Compute size estimate at once to be sure we return it even for
    # old existing windows.
    if { $sizeestimate_p ne "" } {
	upvar $sizeestimate_p ico_size

	set ico_size \
	    [list $tw [expr {$th+[font metrics $BROWSER(-font) -linespace]}]]
    }

    # Check in case we don't already have an icon for that image, if
    # so return it.
    foreach w [winfo children ${top}.canvas] {
	if { [string match "*.ico*" $w]} {
	    if { [winfo exists $w.ico] && [$w.ico cget -text] eq $fullpath } {
		return $w
	    }
	}
    }
    
    # Decide upon the icon to use for the file/directory which is
    # passed as an argument.  At this point even picture files are
    # represented by a picture icon, this icon will be replaced later
    # on by a thumbnail of the picture.
    set fname [file tail $fullpath]
    if { $tcl_platform(platform) eq "windows" \
	     && [file extension $fname] eq ".lnk" } {
	set fullpath [::argutil::resolve_links $fullpath]
    }
    if { [file isdirectory $fullpath] } {
	if { $fname eq ".." } {
	    set img $PB(ico_up)
	} elseif { [file normalize $BROWSER(-root)] eq $fullpath } {
	    set img $PB(ico_home)
	} else {
	    set img $PB(ico_folder)
	}
    } else {
	set mtype [::fileutil::magic::mimetype $fullpath]
	if { [string tolower [lindex [split $mtype "/"] 0]] eq "image" } {
	    set img $PB(ico_image)
	} else {
	    set img $PB(ico_unknown)
	}
    }

    # Now create a frame as a container widget for the icon
    # representation of the file and for its name.
    set fm ${top}.canvas.ico[incr PB(idgene)]
    frame $fm -border 0 -highlightthickness 0
    label $fm.ico -image $img -width $tw -height $th \
	-border 0 -highlightthickness 0 -text "$fullpath" \
	-activebackground white
    label $fm.lbl -font $BROWSER(-font) -border 0 -highlightthickness 0 \
	-activebackground white

    # Compute the maximum text that we can fit under the thumbnail
    # icon, we should be more intelligent about which characters to
    # actually remove, inserting ... in the middle for example to let
    # people understand that the names of the files are bigger.
    set lbltxt $fname
    while { [font measure $BROWSER(-font) $lbltxt] > $tw } {
	set lbltxt [string range $lbltxt 0 end-1]
    }
    $fm.lbl configure -text $lbltxt
    pack $fm.ico -side top -fill both -expand no
    pack $fm.lbl -side bottom -expand no -fill both

    foreach w [list $fm.ico $fm.lbl] {
	if { [file isdirectory $fullpath] } {
	    if { [string is true $BROWSER(-singlebrowse)] } {
		bind $w <Button-1> \
		    +[list ::picbrowser::__choose $top $fullpath]
	    } else {
		bind $w <Double-Button-1> \
		    +[list ::picbrowser::__choose $top $fullpath]
		bind $w <Button-1> \
		    +[list ::picbrowser::__select $top $fm $fullpath]
	    }
	} else {
	    bind $w <Double-Button-1> \
		+[list ::picbrowser::__choose $top $fullpath]
	    bind $w <Button-1> \
		+[list ::picbrowser::__select $top $fm $fullpath]
	}
	if { $PB(dndcapable) && [string is true $BROWSER(-dnd)] } {
	    ::tkdnd::drag_source register $w
	    bind $w <<DragInitCmd>> \
		[list ::picbrowser::__dragsource $top $fullpath]
	}
    }

    # Schedule the replacement of the standard picture icon by a
    # thumbnail of the original picture.  Since thumbnail creation
    # takes time, we do this in an asynchronous manner.  We really
    # should be using some other tricks here, for example using a
    # queue not to convert too many images at once and/or using the
    # "database" of thumbnails that windows explorer sometimes leaves
    # behind in the directories.
    if { $img eq $PB(ico_image) } {
	after idle ::picbrowser::__readimg $fm [list $fullpath]
    }

    return $fm
}


# ::picbrowser::__destroy -- Destruction callback
#
#	This procedure is designed to be bound to destruction events
#	on picture browser.  When such an event is received on a known
#	picture browser, its associated context is removed and all
#	associated resources (images) are deleted.
#
# Arguments:
#	top	Window being destroy (act only on picture browsers)
#
# Results:
#	None
#
# Side Effects:
#	Will remove all resources associated to a picture browser, any
#	call to this library with the picture browser as an argument
#	will fail upon completion.
proc ::picbrowser::__destroy { top } {
    variable PB
    variable log

    # Check that this is one of our browsers
    set idx [lsearch $PB(browsers) $top]
    if { $idx >= 0 } {
	set varname "::picbrowser::browser_${top}"
	upvar \#0 $varname BROWSER
	
	${log}::debug "Destroying resources for $top"

	# Unregister DND
	if { $PB(dndcapable) && [string is true $BROWSER(-dnd)] } {
	    ::tkdnd::drop_target unregister $top.canvas
	}

	# Remove all current icons.
	foreach ico [winfo children ${top}.canvas] {
	    if { [string match "*.ico*" $ico] } {
		__destroyicon $top $ico
	    }
	}
	
	__trigger $top BrowserDestroy

	unset BROWSER
	set PB(browsers) [lreplace $PB(browsers) $idx $idx]
	
	catch {::destroy $top}
    }
}


# ::picbrowser::__choose -- Choose an icon
#
#	This procedure is called back when an icon has been selected
#	(usually by a double click).  Actions are being taken
#	depending on the type of the file.  For example, directories
#	will lead to choosing another directory in the widget.
#
# Arguments:
#	top	Top picture browser widget
#	fname	Name of file being chosen
#
# Results:
#	None
#
# Side Effects:
#	Will trigger appropriate actions.
proc ::picbrowser::__choose { top fname } {
    variable PB
    variable log

    # Check that this is one of our browsers
    set idx [lsearch $PB(browsers) $top]
    if { $idx < 0 } {
	${log}::warn "Browser $top is not valid"
	return -code error "Browser identifier invalid"
    }

    set varname "::picbrowser::browser_${top}"
    upvar \#0 $varname BROWSER

    __trigger $top IconSelect \$fname

    ${log}::debug "Choosing $fname"
    if { [file isdirectory $fname] } {
	set BROWSER(curdir) [file normalize $fname]
	__fill $top
    }
}


# ::picbrowser::__settitle -- Change current title
#
#	This procedure arranges so that the title of the toplevel
#	window carrying a picture browser reflects the title specified
#	under the arguments.  Currently supported symbolic strings,
#	which will be dynamically replaced by their content are: %dir%
#	is the current directory, %reldir% the current directory
#	relative to the home, %home% and %root% are the home of the
#	picture browser, and %nicedir% is a shortened string carrying
#	most of the semantic of the current directory but which is no
#	more that -maxtitlechar characters long.
#
# Arguments:
#	top	Top picture browser widget
#
# Results:
#	None.
#
# Side Effects:
#	None.
proc ::picbrowser::__settitle { top } {
    variable PB
    variable log

    # Check that this is one of our browsers
    set idx [lsearch $PB(browsers) $top]
    if { $idx < 0 } {
	${log}::warn "Browser $top is not valid"
	return -code error "Browser identifier invalid"
    }

    set varname "::picbrowser::browser_${top}"
    upvar \#0 $varname BROWSER

    if { [winfo toplevel $top] == $top } {
	set reldir [file normalize $BROWSER(curdir)]
	if { [string first [file normalize $BROWSER(-root)] $reldir] >= 0 } {
	    set reldir [string range $reldir \
			    [expr [string length [file normalize \
						      $BROWSER(-root)]] +1] \
			    end]
	}
	set nicedir $reldir
	if { [string length $nicedir] > $BROWSER(-maxtitlechar) } {
	    set slash [string first "/" $nicedir]
	    set newdir [string range $nicedir 0 $slash]
	    append newdir ...
	    append newdir [string range $nicedir [expr [string length $nicedir] - $BROWSER(-maxtitlechar) + [string length $newdir]] end]
	    set nicedir $newdir
	}
	set title [regsub -all %nicedir% $BROWSER(-title) $nicedir]
	set title [regsub -all %dir% $title $BROWSER(curdir)]
	set title [regsub -all %reldir% $title $reldir]
	set title [regsub -all %home% $title $BROWSER(-root)]
	set title [regsub -all %root% $title $BROWSER(-root)]
	wm title $top $title
    }
}


# ::picbrowser::__fill -- Fill a picture browser with iconic content.
#
#	This procedure fills in a picture browser with the icons that
#	will represent the content of the current directory.
#
# Arguments:
#	top	Top picture browser widget
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::picbrowser::__fill { top } {
    variable PB
    variable log

    # Check that this is one of our browsers
    set idx [lsearch $PB(browsers) $top]
    if { $idx < 0 } {
	${log}::warn "Browser $top is not valid"
	return -code error "Browser identifier invalid"
    }

    set varname "::picbrowser::browser_${top}"
    upvar \#0 $varname BROWSER

    # Remember all old icons for later removal
    set oldicons [list]
    foreach w [winfo children ${top}.canvas] {
	if { [string match "*.ico*" $w] } {
	    lappend oldicons $w
	}
    }

    __trigger $top BrowserFill \$BROWSER(curdir)

    # Gather all directories under the current directory.
    set dirs [lsort [glob -nocomplain -tails \
			 -directory $BROWSER(curdir) -type d *]]
    if { [file normalize $BROWSER(curdir)] \
	     ne [file normalize $BROWSER(-root)] } {
	set dirs [linsert $dirs 0 ".."]
    }
    if { [string is true $BROWSER(-home)] } {
	set dirs [linsert $dirs 0 [file normalize $BROWSER(-root)]]
    }

    # Gather all files under the current directory
    set files [lsort [glob -nocomplain -tails \
			  -directory $BROWSER(curdir) -type f $BROWSER(-files)]]

    ${log}::debug "Gathered directories:$dirs and files:$files\
                   in $BROWSER(curdir)"
    __settitle $top
    
    # Create and order iconic representations for all directories and
    # files under the current directory.  The icons are widgets that
    # are ordered on a canvas in a grid-fashion.  The algorithm places
    # these widgets on the canvas so that only down scrolling will be
    # possible.
    set x 0
    set y 0
    set w [winfo width ${top}.canvas]
    set h [winfo height ${top}.canvas]
    set newicons [list]
    set filldir $BROWSER(curdir)
    set homepath [file normalize $BROWSER(-root)]
    foreach fname [concat $dirs $files] {
	if { $filldir ne $BROWSER(curdir) } {
	    # Get off if we have managed to already change directory
	    break
	}
	if { $fname eq $homepath } {
	    set fullpath $homepath
	} else {
	    set fullpath [file join $BROWSER(curdir) $fname]
	}
	set ico [__picicon $top $fullpath spacing]
	lappend newicons $ico
	foreach {sw sh} $spacing {}
	#set img [$ico.ico cget -image]
	#set item [${top}.canvas create image $x $y -anchor nw -image $img]
	#${top}.canvas raise $item
	set item [$top.canvas create window $x $y -window $ico -anchor nw \
		     -tags $ico]
	update idletasks
	__trigger $top IconCreate $fullpath $ico

	incr x $sw
	incr x $BROWSER(-spacingx)

	if { [expr $x + $sw] > $w } {
	    set x 0
	    incr y $sh
	    incr y $BROWSER(-spacingy)
	    $top.canvas configure -scrollregion [list 0 0 $w [expr {$y + $sh}]]
	}
    }

    # Remove all existing icons from the browser, for the time being
    # no refresh/append is possible.
    foreach ico $oldicons {
	if { [lsearch -exact $newicons $ico] < 0 } {
	    __destroyicon $top $ico
	}
    }



    set BROWSER(scheduledfill) ""
}


# ::picbrowser::__laterefill -- Lazy re-fill for picbrowser
#
#	This procedure (re)fills the content of a picture browser when
#	its size has changed.  Filling will only take place once the
#	resizing has ended.
#
# Arguments:
#	top	Top pic browser widget
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::picbrowser::__laterefill { top } {
    variable PB
    variable log
 
    # Check that this is one of our browsers
    set idx [lsearch $PB(browsers) $top]
    if { $idx < 0 } {
	${log}::warn "Browser $top is not valid"
	return -code error "Browser identifier invalid"
    }

    set varname "::picbrowser::browser_${top}"
    upvar \#0 $varname BROWSER

    # If size of canvas has changed, schedule fill in a little while.
    set w [winfo width $top.canvas]
    set h [winfo height $top.canvas]
    if { $w != $BROWSER(curwidth) || $h != $BROWSER(curheight) } {
	if { $BROWSER(scheduledfill) ne "" } {
	    after cancel $BROWSER(scheduledfill)
	}
	set BROWSER(curwidth) $w
	set BROWSER(curheight) $h
	
	set BROWSER(scheduledfill) \
	    [after $BROWSER(-redrawfreq) ::picbrowser::__fill $top]
    }
}


# ::picbrowser::__dropdir -- Receive dropped directories
#
#	This procedure is called when a browser receives a directory
#	(via drag-and-drop).  The new directory becomes the root of
#	the picture browser and the browser automatically navigates
#	there.
#
# Arguments:
#	top	Path to pic browser widget
#	fnames	Path to directories or files being dropped.
#
# Results:
#	None
#
# Side Effects:
#	Will actively change the root of the picture browser.
proc ::picbrowser::__dropdir { top fnames } {
    variable PB
    variable log
 
    # Check that this is one of our browsers
    set idx [lsearch $PB(browsers) $top]
    if { $idx < 0 } {
	${log}::warn "Browser $top is not valid"
	return -code error "Browser identifier invalid"
    }

    set varname "::picbrowser::browser_${top}"
    upvar \#0 $varname BROWSER
    
    set dir [lindex $fnames 0]
    ${log}::info "Received dropped filename $dir"
    if { [file isdirectory $dir] } {
	set BROWSER(curdir) $dir
	set BROWSER(-root) $dir
	__fill $top
    }
}


# ::picbrowser::__redraw -- (re)draw the content of a picture browser
#
#	This procedure redraws the content of an existing picture
#	browser.  The content of pictures will automatically be
#	fetched for the representation of the icons.
#
# Arguments:
#	top	Top picbrowser widget
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::picbrowser::__redraw { top } {
    variable PB
    variable log

    # Check that this is one of our browsers
    set idx [lsearch $PB(browsers) $top]
    if { $idx < 0 } {
	${log}::warn "Browser $top is not valid"
	return -code error "Browser identifier invalid"
    }

    set varname "::picbrowser::browser_${top}"
    upvar \#0 $varname BROWSER

    # Create the container for all icons if necessary.
    if { ![winfo exist $top.canvas] } {
	canvas ${top}.canvas -yscrollcommand "${top}.scroll set"
	scrollbar ${top}.scroll -command "${top}.canvas yview"
	#grid ${top}.canvas -row 0 -column 0 -sticky news
	#grid ${top}.scroll -row 0 -column 1 -sticky ns
	pack ${top}.canvas -side left -expand on -fill both
	pack ${top}.scroll -side right -expand off -fill y
	# Fool PrintWindow() windows API call to show a correct
	# background.  This is a hack and don't ask me why it
	# works... :-)
	label ${top}.canvas.bg -text "" -width 400 -height 400
	${top}.canvas create window 0 0 -window ${top}.canvas.bg -anchor nw

	bind $top.canvas <Configure> "::picbrowser::__laterefill $top"
	bind $top.canvas <Destroy> "::picbrowser::__destroy %W"
	if { $PB(dndcapable) && [string is true $BROWSER(-dnd)] } {
	    ${log}::debug "Registering $top.canvas as a drop target"
	    ::tkdnd::drop_target register $top.canvas *
	    bind $top.canvas <<Drop:DND_Files>> \
		"::picbrowser::__dropdir $top %D"
	}
    }

    __laterefill $top
}


# ::picbrowser::new -- Create a new picture browser
#
#	LongDescr.
#
# Arguments:
#	arg1	descr1
#	arg2	descr2
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::picbrowser::new { args } {
    variable PB
    variable log

    if  { [string match "-*" [lindex $args 0]] || [llength $args] == 0 } {
	# Generate a name for the toplevel that does not exist.
	for { set top ".picbrowser$PB(idgene)" } \
	    { [winfo exist $top] } { incr PB(idgene) } {
	    set top ".picbrowser$PB(idgene)"
	}
    } else {
	set top [lindex $args 0]
	set args [lrange $args 1 end]
    }

    set idx [lsearch $PB(browsers) $top]
    if { $idx < 0 } {
	set varname ::picbrowser::browser_${top}
	upvar \#0 $varname BROWSER

	set BROWSER(top) $top
	set BROWSER(curdir) ""
	set BROWSER(scheduledfill) ""
	set BROWSER(curwidth) 0
	set BROWSER(curheight) 0
	set BROWSER(cbs) ""
	lappend PB(browsers) $top

	::uobj::inherit PB BROWSER
	if { ! [winfo exists $top] } {
	    toplevel $top
	}

	rename ::$top ::picbrowser::$top
	proc ::$top { cmd args } [string map [list @w@ ::picbrowser::$top] {
	    set w [namespace tail [lindex [info level 0] 0]]
	    switch -- $cmd {
		config -
		configure {eval ::picbrowser::__config $w $args}
		monitor {eval ::picbrowser::__monitor $w $args}
		default {eval @w@ $cmd $args}
	    }
	}]

	wm protocol $top WM_DELETE_WINDOW "::picbrowser::__destroy $top"
	#bind $top <Destroy> "::picbrowser::__destroy $top"
    }
    
    eval __config $top $args

    return $top
}


# ::picbrowser::__trigger -- Trigger necessary callbacks
#
#	This command relays actions that occur on picture browsers
#	into external callers.  Basically, it calls back all matching
#	callbacks, which implements some sort of event model.
#
# Arguments:
#	top	Top picture browser widget
#	action	Action that occurs (event!)
#	args	Further argument definition for the event.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::picbrowser::__trigger { top action args } {
    variable PB
    variable log

    set varname "::picbrowser::browser_${top}"
    upvar \#0 $varname BROWSER

    # Call all callbacks that have registered for matching actions.
    if { [array names BROWSER cbs] ne "" } {
	foreach {ptn cb} $BROWSER(cbs) {
	    if { [string match $ptn $action] } {
		#${log}::debug "Calling $cb on $top, action $action"
		if { [catch {eval $cb $top $action $args} res] } {
		    ${log}::warn \
			"Error when invoking $action callback $cb: $res"
		}
	    }
	}
    }
}



# ::picbrowser::__monitor -- Event monitoring system
#
#	This command will arrange for a callback every time an event
#	which name matches the pattern passed as a parameter occurs
#	within a picture browser.  The callback will be called with
#	the identifier of the browser, followed by the name of the
#	event and followed by a number of additional arguments which
#	are event dependent.
#
# Arguments:
#	top	Top pic browser widget
#	ptn	String match pattern for event name
#	cb	Command to callback every time a matching event occurs.
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::picbrowser::__monitor { top ptn cb } {
    variable PB
    variable log

    # Check that this is one of our browsers
    set idx [lsearch $PB(browsers) $top]
    if { $idx < 0 } {
	${log}::warn "Browser $top is not valid"
	return -code error "Browser identifier invalid"
    }

    set varname "::picbrowser::browser_${top}"
    upvar \#0 $varname BROWSER

    ${log}::debug "Added <$ptn,$cb> monitor on $top"
    lappend BROWSER(cbs) $ptn $cb
}


# ::picbrowser::__config -- Configure a picture browser
#
#	LongDescr.
#
# Arguments:
#	arg1	descr1
#	arg2	descr2
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::picbrowser::__config { top args } {
    variable PB
    variable log

    # Check that this is one of our browsers
    set idx [lsearch $PB(browsers) $top]
    if { $idx < 0 } {
	${log}::warn "Browser $top is not valid"
	return -code error "Browser identifier invalid"
    }

    set varname "::picbrowser::browser_${top}"
    upvar \#0 $varname BROWSER

    set result [eval ::uobj::config BROWSER "-*" $args]
    if { $BROWSER(curdir) eq "" } {
	set BROWSER(curdir) $BROWSER(-root)
    }
    __redraw $top

    return $result
}


package provide picbrowser 0.2
