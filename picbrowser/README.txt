
			      picbrowser

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The  picbrowser library  implements a  new Tcl/Tk  widget  for the
    navigation  of file hierarchies  that contain  a lot  of pictures.
    During browsing, all pictures within  a directory will be shown as
    thumbnails.  Other files will be shown with standard icons.


The picbrowser library implements a picture browser, i.e. the ability
to navigate a directory hierarchy on the disk, showing iconic
(thumbnail) representation of all images encountered during the
traversal.  The picture browser can be restricted to some file types
via a filter, but will be able to represent files that are not images
using standard default icons.  The browser will recognise windows
links and follow these as the regular explorer.  The picture browser
also supports drag-and-drop operation and will default to "copying"
the file when dropping.

A new picture browser is created via calls to ::picbrowser::new.
Since the picture browser implements a pseudo-widget, the top-level
window that it implements and will create (or fill in) at creation
time will be a command which implements all other operations on the
picture browser.  The picture browser sub-classes the toplevel object,
so all operations unknown to the picture browser will be blindly
forwarded to the top-level.

The picture browser supports the following options, which can be
modified using the configure command:

-thumbsize -- Is a string describing the size of the thumbnails that
will represent pictures.  The dimensions are separated by a x, like in
the geometry specification commands, e.g. 32x32 would tell the browser
to use thumbnails that are 32 pixels wide and high.  The picture
browser will retain the original picture ratio when resizing to
thumbnails, so in the example above, 32 would be the maximum
dimensions along both axis.

-root -- Is the root directory of the hierarchy that is being browsed.
The browser cannot cross this boundary.

-files -- Specifies which files should be shown in the browser.  Files
that do not match this specification will be hidden.  The option is a
string ready for a string match comparison.  It defaults to most of
the known image file types.

-spacingx -- Is the number of pixels between icons along the X axis.

-spacingy -- Is the number of pixels between icons along the Y axis.

-font -- Is the font to use for displaying the file and directory
names.

-redrawfreq -- Specifies the number of milliseconds to wait between
redraws.  Redraws exist because the browser delegates thumbnail
creation to the imgop library and because resizing is a lengthy
operation.

-singlebrowse -- Is a boolean telling whether directories should be
followed and browsed on single click or double click.

-dnd -- Is a boolean telling whether the browser should support
drag-and-drop facilities.  These facilities require access to the
tkdnd extension.

-home -- Is a boolean telling whether a special icon for the "home" of
the browser should be displayed as an icon in the browser at all time.
The "home" is the root of the hierarchy being browsed.

-maxtitlechar -- Is the maximum number of characters for the nice
title of the top-level window (see -title option).  The picture
browser will attempt to make as much of the directory name visible as
possible, "eluding" directories that are in the middle of long path
descriptions.

-title -- Is a string describing the title of the window.  It supports
any string with some syntactic sugar: %dir% is the current directory,
%reldir% the current directory relative to the home, %home% and %root%
are the home of the picture browser, and %nicedir% is a shortened
string carrying most of the semantic of the current directory but
which is no more that -maxtitlechar characters long.

Apart from the configure command, any picture browser instance also
supports the monitor command, which implements a simplistic event
system and allows callers to be notified of (user-driven) events
within the browser.  All commands registered via calls to the monitor
command will be appended the name of the browser, the name of the
action and a number of additional arguments that depend on the event.
Currently, the events supported are the following:

BrowserFill -- is called whenever the browser window is getting filled
with icons, this occurs every time a directory is chosen and followed.
The event takes the current directory as an argument.

BrowserDestroy -- is called whenever the browser is destroyed.

IconCreate -- is called whenever a new "icon" representation for a
file has been created.  It takes the full path to the file and the
name of the icon (a Tk window).

IconInstall -- is called whenever an image has been resized and its
thumbnail has been installed into a browser.  It takes the name of the
file, the path to the widget containing the icon and the image
identifier of the thumbnail.

IconDestroy -- is called whenever an icon is destroyed, probably
because the user has chosen a new directory and because the icons from
the previous directory are being removed.  The event takes the full
path to the file being "removed".

IconActivate -- is called whenever the user has activated an icon,
i.e. focused on an icon via a click of the mouse.  The event takes the
path to the file and the widget containing the icon as arguments.

IconDeactivate -- is the event opposite to IconActivate.

IconSelect -- is called whenever a (directory) icon has been selected,
i.e. chosen, which means that the browser will change directory.  The
event is called with the path to the directory as an argument.

picbrowser is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:picbrowser

