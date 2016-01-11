
			      zlineedit

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The  zlineedit  library provides  facilities  for the  interactive
    edition  of polylines  on  a Zinc  canvas.   The library  provides
    facilities for both the creation of polylines and for the amending
    of  created  polylines.   When  all operations  are  allowed,  the
    library will  arrange for users  to move, remove and  add vertices
    and to move lines by clicking and dragging with the mouse.



The zlineedit provides facilities for the interactive edition of
poly-lines on a Zinc canvas.  The library provides facilities for both
the creation of polylines and for the amending of created polylines.
items on a Zinc canvas.  Depending on a number of configurable
operations, the library will highlight vertices (represented as small
squares) and the polyline and will let users interactively modify the
shape and position of the line with the mouse.  It provides with a
simple event system to let external callers knowing about the various
decisions that it takes.  The library is Zinc specific but could be
adapted to work on top of the regular Tk canvas.

For the time being, the zlineedit library has very little
documentation and you will have to read the code.  Line editors are
created via a single command.  Upon creation, the necessary bindings
will be registered on the canvas.  These will allow the
creation/modification of the line.  Created lines can be detached from
their editors, and new editors will be able to recap on such lines.
New editors should also be able to provide interactive facilities for
polylines that were created on the canvas outside the library.  The
editor will modify the appearance of the line when in edition and when
not, this is fully customisable.

New editors are created with the command ::zlineedit::new, the command
takes a canvas and a number of key values parameters (options).  The
options recognised by the edit "object" are:

-autostart: boolean telling if the bindings for interactive edition
	    should be established at creation time.
-interaction: is a list of keywords that specify the operations that
	      are allowed on the polyline within the editor.  The
	      recognised keywords are VERTEXMOVE VERTEXREMOVE
	      VERTEXADD and LINEMOVE.
-parent: is the identifier of the parent under which the line editor
	 should be created on the canvas.
-roottag: is a prefix that will be prepended to all items that are
	  created by the editor on the canvas.
-linestyle: is the style of the line when not being edited
-lineeditstyle: is the style of the line when being edited
-markerstyle: is the style of the markers when not being edited
-markereditstyle: is the style of the markers when being edited
-markersize: is the size of the markers squares when being edited
-outlinestyle: is the style of the outline behind the line when being edited.

The command returns an identifier for the line editor.  This
identifier identifies the editor uniquely and you can perform a number
of operations on it:

* config will reconfigure the creation options or return these options.

* delete will destroy the line editor and will let the caller decide
  whether the resulting line should be kept or removed from the
  canvas.

* get will return some semi-internal editor properties such as its
  identifier, the canvas to which it is associated or the list of
  vertices that it contains.

* move will programmatically move an editor and its line.

* adding will toggle or get the interaction mode, letting users
  modifying the line according to the modification options when being
  toggled to on.

* insertvertex will add a vertex to an editor.

* removevertex will remove an existing vertex from its editor.

* movevertex will move an existing vertex, and reshape the polyline of
  the editor accordingly.

* vertexlock will lock an existing vertex and make sure that its
  interactive edition will mot be possible.

* monitor will register commands that will be called back upon some
  events.  The recognised events are: VertexMove, VertexRemove,
  VertexInsert, LineMove, Delete.

zlineedit is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:zlineedit
