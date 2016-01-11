
				 osd

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The  osd library  implements  a new  Tcl/Tk  widget that  presents
    itselfs as  an (animated)  notifier that pops  up from one  of the
    side of  the screen in  a direction that  can be chosen.   The osd
    features an image and an informative message.



The osd library provides support for the popping up animation of
toplevel frame less windows from sides of the screen.  Such windows
are present in a number of other software and use to notify the user
of on-going events while the program is hidden (but still active): new
incoming email, connection of new user to a chat program, etc.  This
library is built on top of the notifier library, available from the
same web site.

For the time being, osd has very little documentation and you
will have to read the code.

New osds are created with the command ::osd::new, the command takes
(possibly) the path to a new toplevel osd, together with a number of
key values parameters.  All the options supported by the notifier will
be blindly passed further.  Any other unknown parameter will be passed
to the toplevel creation command.  The options recognised by the osd
are:

-image: The path to the image shown (empty string for no image).
-bg: The background color image.
-text: The text to be shown (empty is allowed).
-justify: Text justification
-font: Font to use for the text.

The command returns the path to the osd.  This path is also a
command on which you can perform a number of operations:

* config (or configure) will reconfigure the creation option.

Any other command will be passed further to the notifier widget.

osd is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:osd

