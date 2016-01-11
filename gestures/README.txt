
			       gestures

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The  gestures  library implements  a  low level Tcl service for
    gesture recognition.  Mouse and keyboard events are pushed into
    the service, which will callback interested parties whenever a
    matching gesture has been recognised.  The library does not draw
    on the screen, this is left to the caller.



The gestures library is a first attempt at a mouse gestures
recognition library.  I looked into using hooking in existing code,
but found that implementing myself was more fun.  The library is at
inception.  The current implementation does not recognise properly
diagonals, which impairs a number of gestures.  I have a number of
ideas on how to extend it to support diagonals and will try to
implement this in a near future.

Note that the gestures library depends on the uobj library, which is
part of the current CVS version of the TIL (see
http://til.sourceforge.net/).

For the time being, gestures has very little documentation and you
will have to read the code. Read on though.

The library implements a low-level service.  Mouse and keyboard
gestures should be caught by the caller and forwarded to the library.
Interested parties will define gestures using strings where characters
have specific meaning: 'D' for down, 'U' for up, 'L' for left, 'R' for
right, 's' for shift, 'c' for conrol and 'a' for alt.  Whenever a
gesture is recognised, the library will performed all registered
callbacks for that gesture with some additional arguments.

The library uses contexts as its core object.  There can be as many
hermetically separated contexts as you wish.  A new gesture context is
created with ::gestures::new, which will return an identifier for the
context.  The command takes a number of key values parameters.  The
options recognised by the gestures are:

-subsample: The amount of motion subsampling pixels (see code).

All further operations are performed through such a context.
::gestures::config will reconfigure a context.  ::gestures::add will
register a new pair gesture string, command to the context, so that
the command can be called whenever the gesture is recognised.  Your
code should push data into the library using ::gestures::push.  Upon
recognition, the callback will be appended the identifier of the
context, the matching gesture definition string and the X and Y centre
of the gesture.

gestures is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:gestures

