
			     capture.dll

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


This module implements a wrapper around the PrintWindow() facility
introducced in Windows XP.  PrintWindow() is able to capture a window
even if it is hidden under other windows on the desktop.  It presents
itself with a little-weird interface so as to be easily interfaced
from scripting languages that can declare commands equivalent for DLL
entries.

The polling frequency is up to the caller, the latest resulting image
being always available.  This library attempts to get around a bug in
PrintWindow which seems to "miss" some zones of the windows sometime.
As a result, the latest capture will only erase totally the previous
capture if there are not too many black pixels, otherwise the capture
will only copy pixels that are not black.  It is also possible to zero
completely the capture buffer from time to time to prevent too bad
captures.

The Makefile is written to allow compilation using MinGW.  This allows
a much smaller toolchain than the free Microsoft compiler and
environment Visual Studio Express.

capture.dll is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

