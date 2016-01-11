
			     fullscreener

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The  fullscreener  library  forces  an existing  window  from  any
    Windows application to remain on  top of a fullscreen blank frame,
    which will ensure  the presence of one and only  one window on the
    screen.



The fullscreener library provides for the ability for a program to
show one and only one window on the screen.  This window can be any
window from a Windows application.  Additionally, the library can
force the window to be kept at the centre of the screen at all time.
The library depends on the winapi library, available from the same
site.

For the time being, fullscreener has very little documentation and you
will have to read the code.

New fullscreeners are created with the command ::fullscreener::new,
the command takes (possibly) the path to a new toplevel fullscreener,
together with a number of key values parameters.  Any other unknown
parameter will be passed to the toplevel creation command.  You will
have to programatically attach the fullscreener to a window later on.
The options recognised by the fullscreener are:

-centered: Should the window be centered at all time.
-period: Period for center checking and enforcement (in milliseconds).

The command returns the path to the fullscreener.  This path is also a
command on which you can perform a number of operations:

* config (or configure) will reconfigure the creation option.
* attach will attach the fullscreener to a window
* detach will detach it (and hide it).

fullscreener is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:fullscreener

