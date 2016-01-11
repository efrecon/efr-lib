
			      flexupdate

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The flexupdate library  aims at minimising the number  of calls to
    the infamous  update command  by issuing calls  to the  command at
    regular intervals only.


The flexupdate library aims at minimising the number of calls to the
infamous update command by filtering calls to the command and letting
them through at regular intervals only.  The library can either be
used as a full replacement for the update command or separately.

To take over all calls to update and filter them under the control of
this library, you should first call ""::flexupdate::takeover"".  If
you wished to stop doing this at a later time, returning to the
regular update behaviour, you should call ""::flexupdate::release"".
It is possible to issue any number of takeover/release pairs under the
life-time of a program.

If you wish to have more controls over how and when to use the
library, you can call ""::flexupdate::update"" yourself.  This command
has the same interface as the regular update command, but offers
filtering under the control of the library.

The library offers a number of library-wide options that can be
queried and changed via the ""::flexupdate::defaults"" command.  These
options are the following:

   -trigger -- is the number of milliseconds to wait before calling
   ""update"".  If the update implementation of the library is called
   more often, only the last call to ""update"" will be let through.
   If this is less or equal than zero, all calls to ""update"" will
   pass through.

   -triggeridle -- is the number of milliseconds to wait before
   calling ""update idletasks"".  If this is less or equal than zero,
   all calls to ""update idletasks"" will be let through.

   -fallback -- is a boolean value.  If it is true, ""update"" calls
   than were filtered away will automatically fall back to this
   library implementation of the ""update idletasks"".  Thus, they
   will follow the rules controlled by the ""-triggeridle"" option.

flexupdate is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:flexupdate
