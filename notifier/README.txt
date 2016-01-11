
			       notifier

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The notifier library implements  a new Tcl/Tk widget that presents
    itselfs as  an (animated)  notifier that pops  up from one  of the
    side  of  the screen  in  a direction  that  can  be chosen.   The
    notifier is a new  toplevel and it is up to the  caller to fill it
    in with content.



The notifier library provides support for the popping up animation of
toplevel frame less windows from sides of the screen.  Such windows
are present in a number of other software and use to notify the user
of on-going events while the program is hidden (but still active): new
incoming email, connection of new user to a chat program, etc.

For the time being, notifier has very little documentation and you
will have to read the code.

New notifiers are created with the command ::notifier::new, the
command takes (possibly) the path to a new toplevel notifier, together
with a number of key values parameters.  Any unknown parameter will be
passed to the toplevel creation command.  The recognised options are:

-anchor: The position of the notifier on the screen.
-animate: The direction for the animation (left, right, down, up).
-withdraw: Should the toplevel be withdrawn at creation?
-offsetx: Offset in pixels from the default anchored position
-offsety: Offset in pixels from the default anchored position
-keyframes: List of milliseconds times for coming in, showing, coming
	    out animation
-manual: Is the notifier manually controlled (hidingin, etc.)
-animation: Period of the animation in milliseconds.

The command returns the path to the notifier.  This path is also a
command on which you can perform a number of operations:

* config (or configure) will reconfigure the creation option.
* show will show the notifier
* hide will hide the notifier
* withdraw will withdraw the notifier (no animation!)
* state returns the current state of the notifier

Any other command will be passed further to the toplevel widget.

winapi is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:notifier

