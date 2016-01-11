
				winapi

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The  winapi library is  a Tcl  library that  offers access  to the
    low-level  Win32 API.   The philosophy  of winapi  is to  give the
    programmer total control over the calls being made, at the expense
    of longer code.  winapi attempts  to mimick as closely as possible
    the Windows  API: it  uses names and  naming conventions  that are
    similar,  offers  Tcl  commands   that  have  the  same  order  of
    arguments,  represents flags  and masks  using the  same  names as
    their Windows  constants counterparts and  represent structures by
    lists  of  even length  containing  the  keys  and values  of  the
    structures.



The winapi library provides an almost one-to-one mapping of (some) of
the Win32 API functions to Tcl programs.  winapi has grown from
missing functionalities in TWAPI, which is otherwise rather similar.
TWAPI misses a number of raw functions and used a syntax that was a
bit odd for experienced Windows programmers.  However, in general
TWAPI covers much more functions from the Win32 API.

Most of the time, MSDN will be your friend and winapi attempts to
mimick as closely as possible the order of the arguments, their names
and the name of the functions and procedures.  Apart from the raw
routines, winapi provides a number of additional utility procedures.
However, winapi is aimed at giving you maximal control over your calls
to the Win32 API.

winapi is written on top of Ffidl (tested with version 0.6) and
declares the necessary entry points for the DLL entries.  All Ffidl
types and winapi procedures belong to the ::winapi:: namespace, some
useful procedures being placed in ::winapi::core.  All internal
procedures or entry points begin with two underscore signs.  winapi is
designed to react upwards as soon as possible, so it does not catch
errors.

For the time being, winapi has very little documentation and you will
have to read the code.  You can interactively get the list of
supported Win32 API commands through running the following code at a
Tcl prompt once you have loaded the winapix or winapi package:

foreach c [info commands ::winapi::*] {
    if { ![string match "*__*" $c] } {
        puts $c
    }
}

Internally, winapi provides three packages: winapi, winapi::core and
winapix, the latter being a set of extra functions that do not map
one-to-one with standard Windows routines.  The implementation of
winapi itself is spread across a number of files, all starting with
wa_ and having winapi.tcl as their central point.

winapi is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:winapi

