# winapi.tcl --
#
#	This module provides an interface to a number of low level
#	WIN32 functions.
#
# Copyright (c) 2004-2006 by the Swedish Institute of Computer Science.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

package require Tcl 8.4
package require logger

# We need Ffidl since we will be creating loads of callouts
package require Ffidl

package require winapi::core

# Create the namespace, further initialisation will be done at the end
# of this file.
namespace eval ::winapi {
    variable WINAPI
    if { ! [info exists WINAPI] } {
	array set WINAPI {
	    version    0.2
	    loglevel   warn
	    unicode    off
	}
	variable log [::logger::init [string trimleft [namespace current] ::]]
	${log}::setlevel $WINAPI(loglevel)
    }
}


# Implementation notes:
#
# All initialisation of structures that are out parameters of windows
# functions should really be done in the way
# ::winapi::GetGUIThreadInfo does things.
#
# There are so many functions that take an structure as an argument
# and fill it in that we really should make this more generic.  That
# would help cleaning the code also.  Maybe ffix is doing something
# similar.



# ::winapi::loglevel -- Set/Get current log level.
#
#	Set and/or get the current log level for this library.
#
# Arguments:
#	loglvl	New loglevel
#
# Results:
#	Return the current log level
#
# Side Effects:
#	None.
proc ::winapi::loglevel { { loglvl "" } } {
    variable WINAPI
    variable log

    if { $loglvl != "" } {
	if { [catch "${log}::setlevel $loglvl"] == 0 } {
	    set WINAPI(loglevel) $loglvl
	}
    }

    return $WINAPI(loglevel)
}




# ::winapi::GetSytemMetrics -- Return system metrics
#
#	This procedure is a wrapper around the GetSystemMetrics.  It
#	recognises all the SM_ flags as an argument.
#
# Arguments:
#	metric	Name of metric to get.
#
# Results:
#	The value of the metric or 0
#
# Side Effects:
#	None.
proc ::winapi::GetSystemMetrics { metric } {
    set m [core::flag $metric [list *CXSCREEN            0 \
				*CYSCREEN            1 \
				*CXVSCROLL           2 \
				*CYHSCROLL           3 \
				*CYCAPTION           4 \
				*CXBORDER            5 \
				*CYBORDER            6 \
				*CXDLGFRAME          7 \
				*CYDLGFRAME          8 \
				*CYVTHUMB            9 \
				*CXHTHUMB           10 \
				*CXICON             11 \
				*CYICON             12 \
				*CXCURSOR           13 \
				*CYCURSOR           14 \
				*CYMENU             15 \
				*CXFULLSCREEN       16 \
				*CYFULLSCREEN       17 \
				*CYKANJIWINDOW      18 \
				*MOUSEPRESENT       19 \
				*CYVSCROLL          20 \
				*CXHSCROLL          21 \
				*DEBUG              22 \
				*SWAPBUTTON         23 \
				*RESERVED1          24 \
				*RESERVED2          25 \
				*RESERVED3          26 \
				*RESERVED4          27 \
				*CXMIN              28 \
				*CYMIN              29 \
				*CXSIZE             30 \
				*CYSIZE             31 \
				*CXFRAME            32 \
				*CYFRAME            33 \
				*CXMINTRACK         34 \
				*CYMINTRACK         35 \
				*CXDOUBLECLK        36 \
				*CYDOUBLECLK        37 \
				*CXICONSPACING      38 \
				*CYICONSPACING      39 \
				*MENUDROPALIGNMENT  40 \
				*PENWINDOWS         41 \
				*DBCSENABLED        42 \
				*CMOUSEBUTTONS      43 \
				*CXFIXEDFRAME        7 \
				*CYFIXEDFRAME        8 \
				*CXSIZEFRAME        32 \
				*CYSIZEFRAME        33 \
				*SECURE             44 \
				*CXEDGE             45 \
				*CYEDGE             46 \
				*CXMINSPACING       47 \
				*CYMINSPACING       48 \
				*CXSMICON           49 \
				*CYSMICON           50 \
				*CYSMCAPTION        51 \
				*CXSMSIZE           52 \
				*CYSMSIZE           53 \
				*CXMENUSIZE         54 \
				*CYMENUSIZE         55 \
				*ARRANGE            56 \
				*CXMINIMIZED        57 \
				*CYMINIMIZED        58 \
				*CXMAXTRACK         59 \
				*CYMAXTRACK         60 \
				*CXMAXIMIZED        61 \
				*CYMAXIMIZED        62 \
				*NETWORK            63 \
				*CLEANBOOT          67 \
				*CXDRAG             68 \
				*CYDRAG             69 \
				*SHOWSOUNDS         70 \
				*CXMENUCHECK        71 \
				*CYMENUCHECK        72 \
				*SLOWMACHINE        73 \
				*MIDEASTENABLED     74 \
				*MOUSEWHEELPRESENT  75 \
				*XVIRTUALSCREEN     76 \
				*YVIRTUALSCREEN     77 \
				*CXVIRTUALSCREEN    78 \
				*CYVIRTUALSCREEN    79 \
				*CMONITORS          80 \
				*SAMEDISPLAYFORMAT  81 \
				*IMMENABLED         82 \
				*CXFOCUSBORDER      83 \
				*CYFOCUSBORDER      84 \
				*TABLETPC           86 \
				*MEDIACENTER        87 \
				*STARTER            88 \
				*SERVERR2           89 \
				*CMETRICS           90]]
    __GetSystemMetrics $m
}


# ::winapi::SystemParametersInfo -- Get/Set system parameters
#
#	Retrieves or sets the value of one of the system-wide
#	parameters.  This function can also update the user profile
#	while setting a parameter.  This procedure needs a lot of
#	extra work to adapt to the various structure pointers used
#	when setting and gettings parameters.
#
# Arguments:
#	action	Action to take (one of the SPI_ constants)
#	ini	Value of the fWinIni parameter
#	args	Remaining arguments, depending on the action to be taken.
#
# Results:
#	Get actions typically return the result either as single
#	values or as lists ready for an array set command.  Empty
#	strings are used on errors.  Set actions return directly the
#	low-level win api result.
#
# Side Effects:
#	None.
proc ::winapi::SystemParametersInfo { action ini args } {
    variable WINAPI
    variable log

    set a [core::flag $action \
	       [list \
		    *SETFOREGROUNDLOCKTIMEOUT  8193 \
		    *GETFOREGROUNDLOCKTIMEOUT  8192 \
		    *GETACCESSTIMEOUT          60 \
		    *GETACTIVEWNDTRKTIMEOUT    8194 \
		    *GETANIMATION              72 \
		    *GETBEEP                   1 \
		    *GETBORDER                 5 \
		    *GETDEFAULTINPUTLANG       89 \
		    *GETDRAGFULLWINDOWS        38 \
		    *GETFASTTASKSWITCH         35 \
		    *GETFILTERKEYS             50 \
		    *GETFONTSMOOTHING          74 \
		    *GETGRIDGRANULARITY        18 \
		    *GETHIGHCONTRAST           66 \
		    *GETICONMETRICS            45 \
		    *GETICONTITLELOGFONT       31 \
		    *GETICONTITLEWRAP          25 \
		    *GETKEYBOARDDELAY          22 \
		    *GETKEYBOARDPREF           68 \
		    *GETKEYBOARDSPEED          10 \
		    *GETLOWPOWERACTIVE         83 \
		    *GETLOWPOWERTIMEOUT        79 \
		    *GETMENUDROPALIGNMENT      27 \
		    *GETMINIMIZEDMETRICS       43 \
		    *GETMOUSESPEED             112 \
		    *GETMOUSEKEYS              54 \
		    *GETMOUSETRAILS            94 \
		    *GETMOUSE                  3 \
		    *GETNONCLIENTMETRICS       41 \
		    *GETPOWEROFFACTIVE         84 \
		    *GETPOWEROFFTIMEOUT        80 \
		    *GETSCREENREADER           70 \
		    *GETSCREENSAVEACTIVE       16 \
		    *GETSCREENSAVETIMEOUT      14 \
		    *GETSERIALKEYS             62 \
		    *GETSHOWSOUNDS             56 \
		    *GETSOUNDSENTRY            64 \
		    *GETSTICKYKEYS             58 \
		    *GETTOGGLEKEYS             52 \
		    *GETWHEELSCROLLLINES       104 \
		    *GETWINDOWSEXTENSION       92 \
		    *GETWORKAREA               48 \
		    *ICONHORIZONTALSPACING     13 \
		    *ICONVERTICALSPACING       24 \
		    *LANGDRIVER                12 \
		    *SCREENSAVERRUNNING        97 \
		    *SETACCESSTIMEOUT          61 \
		    *SETACTIVEWNDTRKTIMEOUT    8195 \
		    *SETANIMATION              73 \
		    *SETBEEP                   2 \
		    *SETBORDER                 6 \
		    *SETDEFAULTINPUTLANG       90 \
		    *SETDESKPATTERN            21 \
		    *SETDESKWALLPAPER          20 \
		    *SETDOUBLECLICKTIME        32 \
		    *SETDOUBLECLKHEIGHT        30 \
		    *SETDOUBLECLKWIDTH         29 \
		    *SETDRAGFULLWINDOWS        37 \
		    *SETDRAGHEIGHT             77 \
		    *SETDRAGWIDTH              76 \
		    *SETFASTTASKSWITCH         36 \
		    *SETFILTERKEYS             51 \
		    *SETFONTSMOOTHING          75 \
		    *SETGRIDGRANULARITY        19 \
		    *SETHANDHELD               78 \
		    *SETHIGHCONTRAST           67 \
		    *SETICONMETRICS            46 \
		    *SETICONTITLELOGFONT       34 \
		    *SETICONTITLEWRAP          26 \
		    *SETKEYBOARDDELAY          23 \
		    *SETKEYBOARDPREF           69 \
		    *SETKEYBOARDSPEED          11 \
		    *SETLANGTOGGLE             91 \
		    *SETLOWPOWERACTIVE         85 \
		    *SETLOWPOWERTIMEOUT        81 \
		    *SETMENUDROPALIGNMENT      28 \
		    *SETMINIMIZEDMETRICS       44 \
		    *SETMOUSE                  4 \
		    *SETMOUSEBUTTONSWAP        33 \
		    *SETMOUSEKEYS              55 \
		    *SETMOUSETRAILS            93 \
		    *SETNONCLIENTMETRICS       42 \
		    *SETPENWINDOWS             49 \
		    *SETPOWEROFFACTIVE         86 \
		    *SETPOWEROFFTIMEOUT        82 \
		    *SETSCREENREADER           71 \
		    *SETSCREENSAVEACTIVE       17 \
		    *SETSCREENSAVERRUNNING     97 \
		    *SETSCREENSAVETIMEOUT      15 \
		    *SETSERIALKEYS             63 \
		    *SETSHOWSOUNDS             57 \
		    *SETSOUNDSENTRY            65 \
		    *SETSTICKYKEYS             59 \
		    *SETTOGGLEKEYS             53 \
		    *SETWHEELSCROLLLINES       105 \
		    *SETWORKAREA               47 \
		    *GETDESKWALLPAPER          115 \
		    *GETSCREENSAVERRUNNING     114 \
		    *GETACTIVEWINDOWTRACKING   4096 \
		    *GETACTIVEWNDTRKZORDER     4108 \
		    *GETCOMBOBOXANIMATION      4100 \
		    *GETCURSORSHADOW           4122 \
		    *GETGRADIENTCAPTIONS       4104 \
		    *GETHOTTRACKING            4110 \
		    *GETKEYBOARDCUES           4106 \
		    *GETLISTBOXSMOOTHSCROLLING 4102 \
		    *GETMENUANIMATION          4098 \
		    *GETMENUFADE               4114 \
		    *GETMENUUNDERLINES         4106 \
		    *GETSELECTIONFADE          4116 \
		    *GETTOOLTIPANIMATION       4118 \
		    *GETTOOLTIPFADE            4120 \
		    *SETACTIVEWINDOWTRACKING   4097 \
		    *SETACTIVEWNDTRKZORDER     4109 \
		    *SETCOMBOBOXANIMATION      4101 \
		    *SETCURSORSHADOW           4123 \
		    *SETGRADIENTCAPTIONS       4105 \
		    *SETHOTTRACKING            4111 \
		    *SETKEYBOARDCUES           4107 \
		    *SETLISTBOXSMOOTHSCROLLING 4103 \
		    *SETMENUANIMATION          4099 \
		    *SETMENUFADE               4115 \
		    *SETMENUUNDERLINES         4107 \
		    *SETMOUSESPEED             113 \
		    *SETSELECTIONFADE          4117 \
		    *SETTOOLTIPANIMATION       4119 \
		    *SETTOOLTIPFADE            4121 \
		    *GETMOUSESONAR             4124 \
		    *SETMOUSESONAR             4125 \
		    *GETMOUSECLICKLOCK         4126 \
		    *SETMOUSECLICKLOCK         4127 \
		    *GETMOUSEVANISH            4128 \
		    *SETMOUSEVANISH            4129 \
		    *GETFLATMENU               4130 \
		    *SETFLATMENU               4131 \
		    *GETDROPSHADOW             4132 \
		    *SETDROPSHADOW             4133 \
		    *GETBLOCKSENDINPUTRESETS   4134 \
		    *SETBLOCKSENDINPUTRESETS   4135 \
		    *GETUIEFFECTS              4158 \
		    *SETUIEFFECTS              4159]]

    set ini [core::flags $ini \
		 [list \
		      *UPDATEINIFILE            1 \
		      *SENDWININICHANGE         2 \
		      *SENDCHANGE               2]]
    switch -glob -- $action {
	"*GETMOUSESONAR" -
	"*GETMOUSEVANISH" -
	"*GETACTIVEWINDOWTRACKING" -
	"*GETACTIVEWNDTRKZORDER" -
	"*GETDRAGFULLWINDOWS" -
	"*GETSHOWIMEUI" {
	    set buf [binary format \
			 x[::ffidl::info sizeof ::winapi::BOOL]]
	    set res [__SystemParametersInfo $a 0 buf $ini]
	    if { $res } {
		binary scan $buf [::ffidl::info format ::winapi::BOOL] val
		return $val
	    } else {
		return ""
	    }
	}
	"*SETMOUSESONAR" -
	"*SETMOUSEVANISH" -
	"*SETACTIVEWINDOWTRACKING" -
	"*SETACTIVEWNDTRKZORDER" -
	"*SETDRAGFULLWINDOWS" -
	"*SETSHOWIMEUI" {
	    set buf [binary format \
			 [::ffidl::info format ::winapi::BOOL] \
			 [string is true [lindex $args 0]]]
	    set res [__SystemParametersInfo $a 0 buf $ini]
	    return $res
	}
	default {
	    return [__SystemParametersInfo_ptr $a 0 0 $ini]
	}
    }

    return ""
}




# ::winapi::__init -- Initialise all known callouts
#
#	This procedure initialises this module by declaring a whole
#	lot of callouts to functions in user32.dll.  All callouts
#	prefixed by __ will be internals for which wrappers are
#	provided.
#
# Arguments:
#	None.
#
# Results:
#	Boolean describe success or failure.
#
# Side Effects:
#	None.
proc ::winapi::__init { } {
    # Declare some windows types.
    ::ffidl::typedef ::winapi::HANDLE uint32
    ::ffidl::typedef ::winapi::HWND ::winapi::HANDLE
    ::ffidl::typedef ::winapi::WORD "unsigned short"
    ::ffidl::typedef ::winapi::DWORD "unsigned long"
    ::ffidl::typedef ::winapi::LONG long
    ::ffidl::typedef ::winapi::BYTE uint8
    ::ffidl::typedef ::winapi::PWORD uint32
    ::ffidl::typedef ::winapi::WINBOOL int
    ::ffidl::typedef ::winapi::BOOL ::winapi::WINBOOL
    ::ffidl::typedef ::winapi::UINT unsigned
    ::ffidl::typedef ::winapi::ATOM ::winapi::WORD
    ::ffidl::typedef ::winapi::LPCTSTR uint32
    ::ffidl::typedef ::winapi::PTR uint32
    ::ffidl::typedef ::winapi::UINT_PTR unsigned
    ::ffidl::typedef ::winapi::LONG_PTR long
    ::ffidl::typedef ::winapi::ULONG_PTR "unsigned long"
    ::ffidl::typedef ::winapi::LPARAM ::winapi::LONG_PTR
    ::ffidl::typedef ::winapi::LRESULT ::winapi::LONG_PTR
    ::ffidl::typedef ::winapi::WPARAM ::winapi::UINT_PTR
    ::ffidl::typedef ::winapi::HRESULT ::winapi::LONG

    ::ffidl::typedef ::winapi::RECT \
	::winapi::LONG ::winapi::LONG ::winapi::LONG ::winapi::LONG
    ::ffidl::typedef ::winapi::POINT \
	::winapi::LONG ::winapi::LONG

    core::api __GetSystemMetrics { int } int
    core::api GetLastError {} int
    core::api __SystemParametersInfo \
	{::winapi::UINT ::winapi::UINT pointer-var ::winapi::UINT} \
	::winapi::BOOL
    core::api __SystemParametersInfo_ptr \
	{::winapi::UINT ::winapi::UINT pointer ::winapi::UINT} \
	::winapi::BOOL SystemParametersInfo

    return 1
}


# Now automatically initialises this module, once and only once
# through calling the __init procedure that was just declared above.
::winapi::core::initonce main ::winapi::__init

package provide winapi $::winapi::WINAPI(version)
