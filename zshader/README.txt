
			       zshader

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The zshader library is a  utility library that will allow to shade
    (fade)  away  items on  a  Zinc  canvas.   The shading  effect  is
    attained  through a stepwise  modification of  the alpha  value of
    groups, which makes this library Zinc specific.



The zshader library is a library that will allow to shade (fade) away
items on a Zinc canvas.  The shading effect is attained through a
stepwise modification of the alpha value of items, which makes this
library Zinc specific.  The library recognises groups and recurses
through all or some of their sub-items when modifying the alpha value.
It provides with a simple event system to let external callers knowing
about the various decisions that it takes.  For the time being, the
library only understands the simplest form of colour specification,
which might break the appearance of the items when advanced
colourisations such as gradients are used.

For the time being, the zshader library has very little documentation
and you will have to read the code.  Basically, a Zinc group is placed
under the control of a zshader, which will modify the alpha value of
the sub-items of the group in a stepwise manner.

New shaders are created with the command ::zshader::new, the command
takes a number of key values parameters (options).  The options
recognised by the shader "object" are:

-autostart: boolean telling if the shading effect should be
	    automatically start at creation time.
-consider: Pattern that the name of the sub-items should match to be
	   considered during the shading effect.
-reject: Same as above, except that these will be rejected for
	 consideration during group traversal.
-time: Number of milliseconds before the item(s) should be made
       completely transparent.
-period: How often should the items be updated? (in milliseconds)
-restoreondelete: If on, this boolean will ensure that the item(s) are
	    	  restored to their original appearance when the
	    	  shader is destroyed.

The command returns an identifier for the shader.  This identifier
identifies the splash window uniquely and you can perform a number of
operations on it:

* config will reconfigure the creation options or return these options.

* delete will destroy and remove the shader window and its associated
  context, possibly restoring the sub-items of the group to their
  original appearance.

* get will return some semi-internal shader properties such as its
  identifier or the canvas to which it is associated.

* restore will instantly stop the shading animation and restore all
  items to their original appearance.

* monitor will register commands that will be called back upon some
  events.  The recognised events are: ItemShade, ItemRestore and
  ItemNew

zshader is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:zshader
