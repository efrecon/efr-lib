# imgop.tcl -- Image operations
#
#	This module provides a number of image operations.  One of the
#	design goals is to provide an abstraction on top of file names
#	and Tk images.
#
# Copyright (c) 2006 by the Swedish Institute of Computer Science.
#
# See the file 'license.terms' for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.4
package require Tk
package require Img

package require uobj
package require argutil
package require diskutil
package require jpeg
package require crc32;  # Turn around until png::imageInfo is fixed
package require png
package require fileutil::magic::mimetype

namespace eval ::imgop {
    variable IMGOP
    if { ! [info exists IMGOP] } {
	array set IMGOP {
	    inited         0
	    -imagemagick   "%libdir%/ImageMagick/%platform%"
	    -tmpext        "png"
	}
	variable libdir [file dirname [file normalize [info script]]]
	::uobj::install_log imgop IMGOP; # Creates 'log' namespace variable
	::uobj::install_defaults imgop IMGOP
    }
}


# ::imgop::__image -- Load in an image from file
#
#	Create a Tk image by loading a file.
#
# Arguments:
#	fname	Name of file to load
#	imgname	Name of image to create
#
# Results:
#	Return the name of the image on success, an empty string on
#	failure.
#
# Side Effects:
#	None.
proc ::imgop::__image { fname { imgname "" } } {
    variable IMGOP
    variable log

    if { $imgname eq "" } {
	if { [catch {image create photo -file $fname} img] } {
	    ${log}::warn "Could not read image file '$fname': $img"
	    return ""
	}
    } else {
	if { [catch {image create photo $imgname -file $fname} img] } {
	    ${log}::warn "Could not read image file '$fname': $img"
	    return ""
	}
    }

    return $img
}


# ::imgop::loadimage -- Load an image from a file
#
#	Load an image using (preferrably) the Img package, otherwise,
#	through converting it using ImageMagick and reverting to one
#	of the standard Tk image formats.
#
# Arguments:
#	fname	Name of file to load
#	imgname	Name of image to create
#
# Results:
#	Return the name of the image that was created, empty string on
#	error.
#
# Side Effects:
#	None.
proc ::imgop::loadimage { fname { imgname "" } } {
    variable IMGOP
    variable log

    set img [__image $fname $imgname]

    if { $img == "" } {
	${log}::info "Converting '$fname' using ImageMagick"
	set mdir [::argutil::resolve_links $IMGOP(-imagemagick)]
	set convert [auto_execok [file join $mdir convert]]
	if { $convert eq "" } {
	    ${log}::warn "Could not find convert in $mdir!"
	    return ""
	}
	set prefix [lindex [split [regsub -all "::" [namespace current] " "]] 0]
	set dst_fname [::diskutil::temporary_file $prefix $IMGOP(-tmpext)]

	set native_in [::diskutil::double_backslash [file nativename $fname]]
	set native_out [::diskutil::double_backslash \
			    [file nativename $dst_fname]]
	if { [catch "exec $convert \"$native_in\" \"$native_out\"" output] } {
	    ${log}::warn "Could not convert to built-in format: $output!"
	    return ""
	} else {
	    set img [__image $dst_fname $imgname]
	    if { $img == "" } {
		${log}::warn "Could not create converted image!"
	    }
	    file delete $dst_fname
	}
    }

    return $img
}


# ::imgop::__gifsize -- Size of a GIF file
#
#	This command actively peeks in a GIF file in order to detect
#	its size.  It is adapted from the code at http://wiki.tcl.tk/758.
#
# Arguments:
#	fname	Path to GIF file.
#
# Results:
#	A list with the width and height of the picture, or an empty
#	list on error.
#
# Side Effects:
#	None.
proc ::imgop::__gifsize { fname} {
    variable IMGOP
    variable log

    set f [open $fname r]
    fconfigure $f -translation binary
    # read GIF signature -- check that this is
    # either GIF87a or GIF89a
    set sig [read $f 6]
    switch $sig {
        "GIF87a" -
        "GIF89a" {
            # do nothing
        }
        default {
            close $f
	    ${log}::warn "$f is not a GIF file"
	    return [list]
        }
    }
    # read "logical screen size", this is USUALLY the image size too.
    # interpreting the rest of the GIF specification is left as an exercise
    binary scan [read $f 2] s wid
    binary scan [read $f 2] s hgt
    close $f

    return [list $wid $hgt]
}


# ::imgop::__bmpsize -- Size of a BMP file
#
#	This command actively peeks in a BMP file in order to detect
#	its size.  It is adapted from the code at http://wiki.tcl.tk/16672.
#
# Arguments:
#	fname	Path to BMP file.
#
# Results:
#	A list with the width and height of the picture, or an empty
#	list on error.
#
# Side Effects:
#	None.
proc ::imgop::__bmpsize { fname} {
    variable IMGOP
    variable log

    set f [open $fname r]
    fconfigure $f -translation binary
    # read BMP signature -- check that this is a BMP file
    set sig [read $f 2]
    if { $sig ne "BM" } {
	close $f
	${log}::warn "$f is not a BMP file"
	return [list]
    }
    seek $f 18; # Past 3 integer header fields
    binary scan [read $f 4] i wid
    binary scan [read $f 4] i hgt
    close $f

    return [list $wid $hgt]
}


# ::imgop::__resize_dimensions -- Compute dimensions for resize
#
#	This command computes the dimensions of the destination image
#	when resizing a source image.  The command is able to keep the
#	ratio of the source image when negative values are passed
#	(either for the width or for the height).
#
# Arguments:
#	name	Name of existing image or of file pointing to an image.
#	width	Destination width of image, keep ratio if negative
#	height	Destination height of image, keep ratio if negative
#
# Results:
#	Return a list of the destination dimensions, an empty list on
#	errors, i.e. when the ratio should be kept and when the
#	routine was not able to guess the dimensions of the original
#	image.
#
# Side Effects:
#	None.
proc ::imgop::__resize_dimensions {name {width -1} {height -1}} {
    variable IMGOP
    variable log

    # If both dimensions are passed as a parameter, we are already
    # done.
    if { $width >= 0 && $height >= 0 } {
	return [list $width $height]
    }

    # Compute dimensions of the original image.
    set sizel [size $name]
    if { $sizel eq "" } {
	${log}::warn "Cannot compute dimensions of $name"
	return [list]
    }
    foreach {iw ih} $sizel {}

    # Compute width and height of destination image, keeping the ratio
    # if necessary
    if { $width < 0 && $height < 0 } {
	${log}::warn \
	    "Both dimensions are negative, returning original dimensions!"
	return [list $iw $ih]
    }

    if { $width < 0 } {
	set ratio [expr double($iw) / double($ih)]
	set width [expr round($height * $ratio)]
    }
    if { $height < 0 } {
	set ratio [expr double($ih) / double($iw)]
	set height [expr round($width * $ratio)]
    }
    
    return [list $width $height]
}


# ::imgop::duplicate -- Duplicate an existing Tk image
#
#	This procedure duplicates an existing Tk image into a new one.
#	If the source image is not an image but a file, then this
#	procedure will behave as the loadimage procedure above.
#
# Arguments:
#	src	Name of source image
#	dst	Optional name of destination
#
# Results:
#	Return the name of the duplica, or an empty string on errors.
#
# Side Effects:
#	None.
proc ::imgop::duplicate { src {dst ""}} {
    variable IMGOP
    variable log

    if { [lsearch -exact [image names] $src] < 0 } {
	return [loadimage $src $dst]
    }

    set sizel [size $src]
    if { $sizel eq "" } {
	${log}::warn "Could not guess dimensions of source image"
	return ""
    }
    foreach {w h} $sizel {}

    if { $dst eq "" } {
	set dst [image create photo -width $w -height $h]
    } else {
	set dst [image create photo $dst -width $w -height $h]
    }
    $dst copy $src

    return $dst
}


# ::imgop::imgresize -- Resize an existing Tk image
#
#	Copies a source image to a destination image and resizes it
#	using linear interpolation.  Shamelessly taken from the wiki:
#	http://wiki.tcl.tk/11196
#
# Arguments:
#	src	Source image
#	newx	Width of new image
#	newy	Height of new image
#	dest	Destination image (optional, in that case generated name)
#
# Results:
#	Name of destination image
#
# Side Effects:
#	None.
proc ::imgop::imgresize { src {newx -1} {newy -1} {dest ""}} {
    variable IMGOP
    variable log

    set sizel [__resize_dimensions $src $newx $newy]
    if { $sizel eq "" } {
	${log}::warn "Could not guess dimensions of destination image"
	return ""
    }
    foreach {newx newy} $sizel {}

    set mx [image width $src]
    set my [image height $src]

    if { "$dest" == ""} {
	set dest [image create photo]
    } elseif { [lsearch [image names] $dest] < 0 } {
	set dest [image create photo $dest]
    }
    $dest configure -width $newx -height $newy

    # Check if we can just zoom using -zoom option on copy
    if { $newx % $mx == 0 && $newy % $my == 0} {

	set ix [expr {$newx / $mx}]
	set iy [expr {$newy / $my}]
	$dest copy $src -zoom $ix $iy
	return $dest
    }

    set ny 0
    set ytot $my

    for {set y 0} {$y < $my} {incr y} {

	#
	# Do horizontal resize
	#

	foreach {pr pg pb} [$src get 0 $y] {break}

	set row [list]
	set thisrow [list]

	set nx 0
	set xtot $mx

	for {set x 1} {$x < $mx} {incr x} {

	    # Add whole pixels as necessary
	    while { $xtot <= $newx } {
		lappend row [format "#%02x%02x%02x" $pr $pg $pb]
		lappend thisrow $pr $pg $pb
		incr xtot $mx
		incr nx
	    }

	    # Now add mixed pixels

	    foreach {r g b} [$src get $x $y] {break}

	    # Calculate ratios to use

	    set xtot [expr {$xtot - $newx}]
	    set rn $xtot
	    set rp [expr {$mx - $xtot}]

	    # This section covers shrinking an image where
	    # more than 1 source pixel may be required to
	    # define the destination pixel

	    set xr 0
	    set xg 0
	    set xb 0

	    while { $xtot > $newx } {
		incr xr $r
		incr xg $g
		incr xb $b

		set xtot [expr {$xtot - $newx}]
		incr x
		foreach {r g b} [$src get $x $y] {break}
	    }

	    # Work out the new pixel colours

	    set tr [expr {int( ($rn*$r + $xr + $rp*$pr) / $mx)}]
	    set tg [expr {int( ($rn*$g + $xg + $rp*$pg) / $mx)}]
	    set tb [expr {int( ($rn*$b + $xb + $rp*$pb) / $mx)}]

	    if {$tr > 255} {set tr 255}
	    if {$tg > 255} {set tg 255}
	    if {$tb > 255} {set tb 255}

	    # Output the pixel

	    lappend row [format "#%02x%02x%02x" $tr $tg $tb]
	    lappend thisrow $tr $tg $tb
	    incr xtot $mx
	    incr nx

	    set pr $r
	    set pg $g
	    set pb $b
	}

	# Finish off pixels on this row
	while { $nx < $newx } {
	    lappend row [format "#%02x%02x%02x" $r $g $b]
	    lappend thisrow $r $g $b
	    incr nx
	}

	#
	# Do vertical resize
	#

	if {[info exists prevrow]} {

	    set nrow [list]

	    # Add whole lines as necessary
	    while { $ytot <= $newy } {

		$dest put -to 0 $ny [list $prow]

		incr ytot $my
		incr ny
	    }

	    # Now add mixed line
	    # Calculate ratios to use

	    set ytot [expr {$ytot - $newy}]
	    set rn $ytot
	    set rp [expr {$my - $rn}]

	    # This section covers shrinking an image
	    # where a single pixel is made from more than
	    # 2 others.  Actually we cheat and just remove
	    # a line of pixels which is not as good as it should be

	    while { $ytot > $newy } {

		set ytot [expr {$ytot - $newy}]
		incr y
		continue
	    }

	    # Calculate new row

	    foreach {pr pg pb} $prevrow {r g b} $thisrow {

		set tr [expr {int( ($rn*$r + $rp*$pr) / $my)}]
		set tg [expr {int( ($rn*$g + $rp*$pg) / $my)}]
		set tb [expr {int( ($rn*$b + $rp*$pb) / $my)}]

		lappend nrow [format "#%02x%02x%02x" $tr $tg $tb]
	    }

	    $dest put -to 0 $ny [list $nrow]

	    incr ytot $my
	    incr ny
	}

	set prevrow $thisrow
	set prow $row

	update idletasks
    }

    # Finish off last rows
    while { $ny < $newy } {
	$dest put -to 0 $ny [list $row]
	incr ny
    }
    update idletasks

    return $dest
}


# ::imgop::size -- Return the size of an image
#
#	Actively computes the size of an image and return it.  This
#	command is both able to handle file names and existing Tk
#	images.  Files will not be loaded into memory.
#
# Arguments:
#	name	Name of existing image or of file pointing to an image.
#
# Results:
#	Return a list with the width and height of the image, an empty
#	list on errors.
#
# Side Effects:
#	None.
proc ::imgop::size { name } {
    variable IMGOP
    variable log

    if { [lsearch -exact [image names] $name] < 0 } {
	${log}::debug "Image $name is a file on disk, guessing"
	if { [::jpeg::isJPEG $name] } {
	    return [::jpeg::dimensions $name]
	} elseif { [::png::isPNG $name] } {
	    array set imginfo [::png::imageInfo $name]
	    return [list $imginfo(width) $imginfo(height)]
	} elseif { [::fileutil::magic::mimetype $name] eq "image/gif" } {
	    return [__gifsize $name]
	} elseif { [::fileutil::magic::mimetype $name] eq "image/x-bmp" } {
	    return [__bmpsize $name]
	} else {
	    # The image is of none of the internally recognised types,
	    # use image magick to get its size, this is heavy but our
	    # only solution.
	    set mdir [::argutil::resolve_links $IMGOP(-imagemagick)]
	    set identify [auto_execok [file join $mdir identify]]
	    if { $identify eq "" } {
		${log}::warn "Could not find identify in $mdir!"
		return [list]
	    }
	    ${log}::debug "Using identify at $identify to detect image size"
	    set native_fname \
		[::diskutil::double_backslash [file nativename $name]]
	    set res -1
	    set output ""
	    if { $identify != "" } {
		set res [catch "exec $identify \"$native_fname\"" output]
	    }
	    if { $res == 0 } {
		set geo 0
		foreach item $output {
		    if { [regexp "\\d+x\\d+" $item] } {
			# Initialise to item, in case it is in the format WxH
			set geo $item
			# Now get rid of strange and stupid ending placement
			# in the X format.
			set minus [string first "-" $item]
			if { $minus >= 0 } {
			    set geo [string range $item 0 [expr $minus - 1]]
			}
			set plus [string first "+" $item]
			if { $plus >= 0 } {
			    set geo [string range $item 0 [expr $plus - 1]]
			}
			return [split $geo "x"]
		    }
		}
		${log}::warn \
		    "Could not find image geometry information in $output"
	    } else {
		${log}::error "Exec error: $output"
	    }
	    return [list]
	}
    } else {
	${log}::debug "Image $name is an internal image"
	return [list [image width $name] [image height $name]]
    }

    return [list]
}


# ::imgop::magickresize -- Resize an image via Image Magick
#
#	This command resizes an image via Image Magick.  If the image
#	is a Tk image, a temporary file will be used both for holding
#	a copy of the source image and for holding a copy of the
#	destination (resized) image.  This command allows external
#	callers to pass further arguments to Image Magick.
#
# Arguments:
#	name	Name of Tk image or path to image file on disk
#	width	Destination width of image, keep ratio if negative
#	height	Destination height of image, keep ratio if negative
#	args	Additional arguments to ImageMagick when operating from disk
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::imgop::magickresize { name { width -1 } { height -1 } args } {
    variable IMGOP
    variable log

    # Compute dimensions of destination image.
    set sizel [__resize_dimensions $name $width $height]
    if { $sizel eq "" } {
	${log}::warn "Could not guess dimensions of destination image"
	return ""
    }
    foreach {width height} $sizel {}

    # Create temporary file with content of source file, preferrably
    # in a non destructive compression format.
    set prefix [lindex [split [regsub -all "::" [namespace current] " "]] 0]
    if { [lsearch -exact [image names] $name] >= 0 } {
	set fname [::diskutil::temporary_file $prefix $IMGOP(-tmpext)]
	if { [catch {$img write -format png $fname} err] } {
	    ${log}::warn "Could not write image to temporary file $fname"
	    return ""
	}
    } else {
	set fname $name
    }

    # Now resize using image magick, appending the necessary arguments
    # to the convert executable.
    set geo "${width}x${height}"
    ${log}::debug "Resizing image '$name' to $geo"

    set mdir [::argutil::resolve_links $IMGOP(-imagemagick)]
    set convert [auto_execok [file join $mdir convert]]
    if { $convert eq "" } {
	${log}::warn "Could not find convert in $mdir!"
	return ""
    }

    set dst_fname [::diskutil::temporary_file $prefix $IMGOP(-tmpext)]

    if {1} {
	set native_in [::diskutil::double_backslash \
			   [file nativename [file normalize $fname]]]
	set native_out [::diskutil::double_backslash \
			    [file nativename [file normalize $dst_fname]]]
    } else {
	set native_in [file normalize $fname]
	set native_out [file normalize $dst_fname]
    }
    set cmd "exec $convert $args -resize \"${geo}!\""
    append cmd " \"$native_in\" \"$native_out\""
    if { [catch $cmd output] } {
	${log}::warn "Could not resize image via Image Magick: $output!"
	return ""
    }
    
    # Create destination image and clean up temporary files.
    if { [catch {image create photo -file $dst_fname} rszimg] } {
	${log}::warn "Could not read resized image: $rszimg!"
	set rszimg ""
    }
    
    if { $name ne $fname } {
	file delete $fname
    }
    file delete $dst_fname

    return $rszimg
}


# ::imgop::resize -- Resize an image
#
#	Resize an image, whether it is an in-memory Tk image or an
#	image on disk
#
# Arguments:
#	name	Name of Tk image or path to image file on disk
#	width	Destination width of image, keep ratio if negative
#	height	Destination height of image, keep ratio if negative
#	args	Additional arguments to ImageMagick when operating from disk
#
# Results:
#	Return the name of the resized image or an empty string on error.
#
# Side Effects:
#	Will use temporary files when resizing on disk.
proc ::imgop::resize { name { width -1 } { height -1 } args } {
    variable IMGOP
    variable log

    # Compute dimensions of destination image.
    set sizel [__resize_dimensions $name $width $height]
    if { $sizel eq "" } {
	${log}::warn "Could not guess dimensions of destination image"
	return ""
    }
    foreach {width height} $sizel {}

    # Resize image
    if { [lsearch -exact [image names] $name] < 0 } {
	return [eval magickresize \$name $width $height $args]
    } else {
	return [imgresize $name $width $height]
    }    
}


# ::imgop::histogram -- Compute picture histogram
#
#	This command computes the histogram of a given picture, the
#	histogram is returned in the form of a sorted list with the
#	color of the highest intensity first.
#
# Arguments:
#	img	Tk image
#
# Results:
#	Return a 4-sized list where the quadruplets contain the r, g,
#	b and frequency values of the sorted histogram.
#
# Side Effects:
#	None.
proc ::imgop::histogram { img } {
    variable IMGOP
    variable log

    ${log}::debug "Computing histogram for $img"

    # Compute histogram in local array
    array set hist {}
    set w [image width $img]
    set h [image height $img]
    for { set x 0 } { $x < $w } { incr x } {
	for { set y 0 } { $y < $h } { incr y } {
	    foreach {r g b} [$img get $x $y] {}
	    set idx [format "%02x%02x%02x" $r $g $b]
	    if { [array names hist $idx] eq "" } {
		set hist($idx) 1
	    } else {
		incr hist($idx)
	    }
	}
    }

    # Convert the histogram to a list appropriate for sorting
    set outlist [list]
    foreach i [array names hist] {
	scan $i "%02x%02x%02x" r g b
	lappend outlist [list $r $g $b $hist($i)]
    }

    # Sort and return list in appropriate format
    return [eval concat [lsort -index 3 -integer -decreasing $outlist]]
}


# ::imgop::pixcounter -- Apply pixel rules on image
#
#	Apply a rule on all pixels.  A rules can be any string
#	compatible with expr, where the strings R, G and B will be
#	replaced by the RGB value of the pixel.  The number of
#	matching pixels is returned.
#
# Arguments:
#	img	Tk image
#	rules	Rules to apply within image.
#
# Results:
#	Return the number of pixels matching the rules.
#
# Side Effects:
#	None.
proc ::imgop::pixcounter { img rules } {
    variable IMGOP
    variable log
    
    ${log}::debug "Applying pixel rules '$rules' on image $img"

    set match 0
    set w [image width $img]
    set h [image height $img]
    for { set x 0 } { $x < $w } { incr x } {
	for { set y 0 } { $y < $h } { incr y } {
	    foreach {r g b} [$img get $x $y] {}
	    set prule [string map [list "R" $r "G" $g "B" $b] $rules]
	    if { [expr $prule] } {
		incr match
	    }
	}
    }

    return $match
}


# ::imgop::transparent -- Make pixels in an image transparent
#
#	Makes all pixels of a given colour in a Tk image transparent.
#	Colour selection is based on expressions, so that all < or >
#	or any other signs can be used.  The current colour of the
#	image pixel is always prepended to the expression before being
#	evaluated.  Simple integers will automatically be amended and
#	prepended with ==, which is the default awaited (and original)
#	behaviour of this procedure!
#
# Arguments:
#	img	Image to process.
#	bg	RGB list of "background" colour expressions to make transparent
#
# Results:
#	Return the number of pixels that were made transparent.
#
# Side Effects:
#	None.
proc ::imgop::transparent { img { bg "0 0 0" } } {
    variable IMGOP
    variable log

    ${log}::debug "Making pixels in image $img transparent: $bg"
    set no_trans 0

    foreach {bg_r bg_g bg_b} $bg break
    if { [string is integer $bg_r] } {
	set exp_r " == $bg_r"
    } else {
	set exp_r " $bg_r"
    }
    if { [string is integer $bg_g] } {
	set exp_g " == $bg_g"
    } else {
	set exp_g " $bg_g"
    }
    if { [string is integer $bg_b] } {
	set exp_b " == $bg_b"
    } else {
	set exp_b " $bg_b"
    }


    set w [image width $img]
    set h [image height $img]
    for { set xx 0 } { $xx < $w } { incr xx } {
	for { set yy 0 } { $yy < $h } { incr yy } {
	    foreach {r g b} [$img get $xx $yy] break
	    if { [expr $r $exp_r] && [expr $g $exp_g] && [expr $b $exp_b] } {
		incr no_trans
		$img transparency set $xx $yy 1
	    }
	}
    }

    ${log}::notice "Made $no_trans pixel(s) transparent in $img"

    return $no_trans
}


# ::imgop::opaque -- Make an image opaque
#
#	Make all transparent pixels of an image non-transparent,
#	possibly changing their color.
#
# Arguments:
#	img	Image to process
#	bg	RGB value for opacified pixels (either #started or rgb triplet)
#
# Results:
#	Return the number of pixels that were changed.
#
# Side Effects:
#	None.
proc ::imgop::opaque { img { bg "" } } {
    variable IMGOP
    variable log

    ${log}::debug "Making pixels in imag $img opaque: $bg"
    set no_changed 0

    # Handle triplets
    if { [llength $bg] == 3 } {
	foreach {r g b} $bg break
	set bg [format "#%02x%02x%02x" $r $g $b]
    }

    set w [image width $img]
    set h [image height $img]
    for { set xx 0 } { $xx < $w } { incr xx } {
	for { set yy 0 } { $yy < $h } { incr yy } {
	    if { [$img transparency get $xx $yy] } {
		$img transparency set $xx $yy 0
		incr no_changed
		if { $bg ne "" } {
		    $img put -to $xx $yy $bg
		}
	    }
	}
    }

    ${log}::notice "Made $no_changed pixel(s) transparent in $img"

    return $no_changed
}



# ::imgop::__init -- Initialise module
#
#	This command initialises the module internals once and only once.
#
# Arguments:
#	None
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::imgop::__init { } {
    variable IMGOP
    variable log
    variable libdir

    if { ! $IMGOP(inited) } {
	# See to resolve all the symbolic paths that are part of the
	# default arguments.
	foreach opt [list -imagemagick] {
	    set IMGOP($opt) [regsub -all "%libdir%" $IMGOP($opt) $libdir]
	    set IMGOP($opt) [regsub -all "%platform%" $IMGOP($opt) \
				 [::argutil::platform]]
	    set IMGOP($opt) [::diskutil::fname_resolv $IMGOP($opt)]
	}
	set IMGOP(inited) 1
    }
}

# Initialise this module once and only once.
::imgop::__init

package provide imgop 0.1
