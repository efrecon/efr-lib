
			     floatingbbar

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The  floatingbbar  library implements  a  new  Tcl/Tk widget  that
    presents itself as an (animated)  floating button bar that pops up
    from one  of the  side of the  screen in  a direction that  can be
    chosen.  The floatingbbar features any number of buttons.



The floatingbbar library provides support for a button bar that will
pop up from one side of the screen whenever the mouse hoovers into
it. It is useful when trying to save screen space while letting users
know that there are more commands available if they need it.  The
library geared towards fullscreen applications but can be used in any
other settings.  The library is built on top of the notifier library,
available from the same site.

For the time being, floatingbbar has very little documentation and you
will have to read the code.

New floatingbbars are created with the command ::floatingbbar::new,
the command takes (possibly) the path to a new toplevel floatingbbar,
together with a number of key values parameters.  The options
recognised by the floatingbbar are:

-bg: The background color image.
-pad: Padding in pixels between buttons.
-side: Side of the bbar (always centered): right, left, top, bottom
-content: An even list describing the content of the button bar. First
	  item is the path to an image, second item is the command to
	  associate to the button.

The command returns the path to the floatingbbar.  This path is also a
command on which you can perform a number of operations:

* config (or configure) will reconfigure the creation options.

Any other command will be passed further to the notifier widget.

floatingbbar is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:floatingbbar

