
				imgop

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The  imgop library implements  a number  of operations  on images.
    The library implements some these  operations in pure Tcl and some
    other  operations   through  the  help   of  ImageMagick,  without
    requesting any dynamic binding to the program.



The imgop library provides a number of routines to perform common
operations on images.  It attempts to performs as much of these
operations as possible in pure Tcl, on top of the standard features of
the image command.  When such operations are not possible, when
turn-arounds exist or when speed is crucial, the library relies on an
installation of ImageMagick.  As opposed to pure dynamic bindings such
as TclMagick, the imgop library will simply execute the appropriate
binary from the ImageMagick suite whenever necessary.

Finally, another design principle of the library is to hide (or at
least fade out) the differences between Tk images and files on disk.
Consequently, a number of procedures accept both type of arguments and
are able to operate and reason about the image in an abstract manner.
Most of the time, this will be what you want (at least what I wanted).

This library has been tested on Windows and Linux.  Windows being my
main development platform nowadays, Linux is something that I have
tested less, and there might be errors left.  ImageMagick comes with
most Linux distributions, so the library supposes to be able to find
the binaries from the execution path.  On Windows, things are usually
harder.  Consequently, the library is also able to find platform
specific binaries in the ImageMagick sub-directory.  I have placed
there a slightly cleaned up version of ImageMagick for Windows.  This
version is statically bound (to avoid DLL hell) and is a Q16 compiled
distribution (i.e. it represents pixel component values on 16 bits for
better results).

The library depends on a number of other libraries, so you are better
off with a batteries included installation.  However, the dependency
that I recall are on tcllib, on the Img package and on my TIL package,
which is a sourceforge project.

For the time being, the imgop library has very little documentation
and you will have to read the code.  The following commands are
available at the time of writing:

* ::imgop::loglevel sets the level of log for the library.  These
  levels are from the logger library.

* ::imgop::defaults allows to get and set some of the default values
  for the routines.  These are traditional key value pairs where the
  keys are dash-led (as in Tk!). The -imagemagick option dictates
  where to find the ImageMagick installation (you should not have to
  modify this really).  The -tmpext dictates the extension to use for
  temporary files, this should preferrably be a non-destructive image
  compression format that is recognised by the Img package.

* ::imgop::loadimage is a wrapper around "image create photo -file".
  The function attempts to load the image using the standard Tk image
  library first, then via an ImageMagick conversion if that failed.
  This allows for the support of more file formats and for the support
  of formats that are badly supported, for example 32bits Windows
  bitmaps.

* ::imgop::duplicate duplicates an existing image.

* ::imgop::imgresize is a pure Tcl image resizing routine, and as
  such, it will be slow (and produce erroneous results for pixels that
  contain transparency for the time being).

* ::imgop::magickresize is an image/file agnostic routine that uses
  ImageMagick to resize an image, possibly via a temporary file.  The
  routine internally uses convert and let you specifying additional
  arguments that will be passed to the conversion binary, allowing for
  extra operations for those who know how to use ImageMagick.

* ::imgop::resize is a wrapper around the two routines above.  It
  will resize Tk image using pure Tcl and files on disk using
  ImageMagick.

* ::imgop::size is an image/file agnostic routine that actively
  guesses the size of an image.  When operating on files, it relies on
  a number of file peeking for some well-known types and on
  ImageMagick as a fail safe solution if these are not possible.

* ::imgop::pixcounter counts the number of pixels matching a given
  rule.  The rule is an expression (as in expr) where the string R, G
  and B will be replaced by the RGB values at each pixel.

* ::imgop::transparent is able to make some pixels transparent in an
  existing picture.  Transparency is selected upon the RGB value of
  the pixels.

* ::imgop::opaque is the opposite operation and will make all
  transparent pixels opaque, possibly changing their RGB value.  It is
  perfect for using transparent GIFs as shaped windows using the
  tktrans extension for example.

imgop is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:imgop

