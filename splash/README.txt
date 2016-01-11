
				splash

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The splash  library implements a  new Tcl/Tk toplevel  widget that
    aims  at   showing  one  (or  more)  splash   windows  during  the
    initialisation  phase  of  an  application or  any  other  lengthy
    operation.



The splash library provides routines to create and control splash
windows.  Splash windows are frameless windows that appear on top of
other windows when an application initialises or performs a lengthy
operation.  The library is tuned to be called as soon as an
application initialises so as to let the splash window appear as soon
as possible and thus let the user know that something is happening,
which is the purpose of most splash windows.  Consequently, the
library is built on top of the base Tk widgets and does not require
any other library.

For the time being, the splash library has very little documentation
and you will have to read the code.  Basically, splash windows are
composed of a picture (preferrably of one of the types recognised by
base Tk, i.e. without the help of the Image library or similar) and an
optional progress bar and message information.

New splash windows are created with the command ::splash::new, the
command takes a number of key values parameters.  This command returns
the name of the toplevel that has been created. The options recognised
by the splash "object" are:

-imgfile: Path to the image that will be shown, empty to disable.
-progress: Number of logical operations that the splash window will
           show via a progress bar that will automatically appear when
           this number is greater than 0.
-text: Boolean telling whether the splash window features a text info
       or not.
-anchor: Anchor that specifies the location of the splash on the
 	 screen, defaults to "c" (i.e. centered!).
-hidemain: Boolean that will see to automatically hide the main (.)
 	   window on start up and restore that window when the splash
 	   is destroyed.
-hideall: Boolean that will see to attempt hiding all toplevel windows
	  on startup and restore these once the splash is removed.
	  This is an experimentary feature that works by overloading
	  the toplevel command.
-delay: Number of milliseconds after which the splash window is
	automatically destroyed, if less or equal than zero, you will
	have to destroy the window yourself (this is the default).
-autoraise: Automatically raise the window whenever it "progresses"
-topmost: Keep the window on top of all windows, on Windows only.
-alpha: Set the transparency of the window, only on the platforms that
 	supports it.

The command returns the path to the splash window.  This path
identifies the splash window uniquely and you can perform a number of
operations on it:

* config will reconfigure the creation options, reconfiguration also
  includes the possibility to add features to the splash window at a
  later time or the ability to change its bitmap.

* destroy will destroy and remove the splash window and its associated
  context, possibly showing back the main window.  You can also simply
  destroy the toplevel using the regular Tk destroy command.

* progress makes the splash window progress through its various
  initialisation steps, or similar.  Apart from the path to a splash
  window, the command takes a text string and an increment as an
  argument.  The text string will be shown in the appropriate text
  info, and the increment will be added to the current progress level.
  These features are only shown if the splash was created (or
  configured) so.

splash is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:splash

