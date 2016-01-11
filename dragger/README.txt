
			       dragger

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The dragger library  implements the back end support  for drag and
    drop of  icons, i.e.  Tk widgets.  The  library will take  care of
    creating the dragged icon and  of the animation and will deliver a
    callback when the icon is dropped.


The dragger library provides the back end support for drag/drop of
icons.  It purpose is to follow mouse movements with icons that may be
shaped.  It allows to register any Tk widget path as a drag source; on
button press, an image icon (possibly shaped) will be created and will
follow the mouse cursor until release of the button.  On button
release, the library delivers a callback.  On windows, the library
uses the services of a (slightly modified) tktrans implementation for
dragging shaped windows.
   
A dragger is the drag-and-drop context associated to a window path.
Draggers are created via the ::dragger::new command and can be
reconfigured whenever needed.  Apart from the widget source and the
image that will be dragged, they recognise the following options:
   
   -buttons -- is a list of buttons that will be recognised for
   triggering a drag operation.

   -drop -- is a list of commands that will be called when a dragged
   icon is being dropped.  The commands will be called with the
   following arguments: path to the source widget, button that was
   press and released, position of the mouse pointer in X, in Y.

   -topmost -- is a boolean that will force the dragged icon to be
   topmost on windows.

   -indirector -- is the path to the window on which mouse events
   should be listened when a drag has started.  This exists to allow
   dragging items that are placed on a canvas.

dragger is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:dragger
