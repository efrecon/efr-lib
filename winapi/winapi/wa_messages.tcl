package require winapi::core

namespace eval ::winapi {
    variable WINAPI
    variable log
}


# ::winapi::__Message -- Message dispatcher.
#
#	The command sends/posts the specified message to an object.
#	The delivery function is an argument to this function itself.
#	The procedure is a single entry wrapper to avoid the long list
#	of allowed messages.
#
# Arguments:
#	w	Handle of window.
#	msg	Message
#	prm1	First parameter of message
#	prm2	Second parameter of message
#	fn	Function to send/post message
#
# Results:
#	The result of the called function
#
# Side Effects:
#	None.
proc ::winapi::__Message { id msg wparam lparam fn } {
    set msg [core::flag $msg [list \
			      *NULL                       [expr 0x0] \
			      *CREATE                     [expr 0x1] \
			      *DESTROY                    [expr 0x2] \
			      *MOVE                       [expr 0x3] \
			      *SIZEWAIT                   [expr 0x4] \
			      *SIZE                       [expr 0x5] \
			      *ACTIVATE                   [expr 0x6] \
			      *SETFOCUS                   [expr 0x7] \
			      *KILLFOCUS                  [expr 0x8] \
			      *SETVISIBLE                 [expr 0x9] \
			      *ENABLE                     [expr 0xa] \
			      *SETREDRAW                  [expr 0xb] \
			      *SETTEXT                    [expr 0xc] \
			      *GETTEXT                    [expr 0xd] \
			      *GETTEXTLENGTH              [expr 0xe] \
			      *PAINT                      [expr 0xf] \
			      *CLOSE                      [expr 0x10] \
			      *QUERYENDSESSION            [expr 0x11] \
			      *QUIT                       [expr 0x12] \
			      *QUERYOPEN                  [expr 0x13] \
			      *ERASEBKGND                 [expr 0x14] \
			      *SYSCOLORCHANGE             [expr 0x15] \
			      *ENDSESSION                 [expr 0x16] \
			      *SYSTEMERROR                [expr 0x17] \
			      *SHOWWINDOW                 [expr 0x18] \
			      *CTLCOLOR                   [expr 0x19] \
			      *WININICHANGE               [expr 0x1a] \
			      *SETTINGCHANGE              [expr 0x1a] \
			      *DEVMODECHANGE              [expr 0x1b] \
			      *ACTIVATEAPP                [expr 0x1c] \
			      *FONTCHANGE                 [expr 0x1d] \
			      *TIMECHANGE                 [expr 0x1e] \
			      *CANCELMODE                 [expr 0x1f] \
			      *SETCURSOR                  [expr 0x20] \
			      *MOUSEACTIVATE              [expr 0x21] \
			      *CHILDACTIVATE              [expr 0x22] \
			      *QUEUESYNC                  [expr 0x23] \
			      *GETMINMAXINFO              [expr 0x24] \
			      *PAINTICON                  [expr 0x26] \
			      *ICONERASEBKGND             [expr 0x27] \
			      *NEXTDLGCTL                 [expr 0x28] \
			      *ALTTABACTIVE               [expr 0x29] \
			      *SPOOLERSTATUS              [expr 0x2a] \
			      *DRAWITEM                   [expr 0x2b] \
			      *MEASUREITEM                [expr 0x2c] \
			      *DELETEITEM                 [expr 0x2d] \
			      *VKEYTOITEM                 [expr 0x2e] \
			      *CHARTOITEM                 [expr 0x2f] \
			      *SETFONT                    [expr 0x30] \
			      *GETFONT                    [expr 0x31] \
			      *SETHOTKEY                  [expr 0x32] \
			      *GETHOTKEY                  [expr 0x33] \
			      *FILESYSCHANGE              [expr 0x34] \
			      *ISACTIVEICON               [expr 0x35] \
			      *QUERYPARKICON              [expr 0x36] \
			      *QUERYDRAGICON              [expr 0x37] \
			      *QUERYSAVESTATE             [expr 0x38] \
			      *COMPAREITEM                [expr 0x39] \
			      *TESTING                    [expr 0x3a] \
			      *GETOBJECT                  [expr 0x3d] \
			      *ACTIVATESHELLWINDOW        [expr 0x3e] \
			      *COMPACTING                 [expr 0x41] \
			      *COMMNOTIFY                 [expr 0x44] \
			      *WINDOWPOSCHANGING          [expr 0x46] \
			      *WINDOWPOSCHANGED           [expr 0x47] \
			      *POWER                      [expr 0x48] \
			      *COPYDATA                   [expr 0x4a] \
			      *CANCELJOURNAL              [expr 0x4b] \
			      *NOTIFY                     [expr 0x4e] \
			      *INPUTLANGCHANGEREQUEST     [expr 0x50] \
			      *INPUTLANGCHANGE            [expr 0x51] \
			      *TCARD                      [expr 0x52] \
			      *HELP                       [expr 0x53] \
			      *USERCHANGED                [expr 0x54] \
			      *NOTIFYFORMAT               [expr 0x55] \
			      *CONTEXTMENU                [expr 0x7b] \
			      *STYLECHANGING              [expr 0x7c] \
			      *STYLECHANGED               [expr 0x7d] \
			      *DISPLAYCHANGE              [expr 0x7e] \
			      *GETICON                    [expr 0x7f] \
			      *SETICON                    [expr 0x80] \
			      *NCCREATE                   [expr 0x81] \
			      *NCDESTROY                  [expr 0x82] \
			      *NCCALCSIZE                 [expr 0x83] \
			      *NCHITTEST                  [expr 0x84] \
			      *NCPAINT                    [expr 0x85] \
			      *NCACTIVATE                 [expr 0x86] \
			      *GETDLGCODE                 [expr 0x87] \
			      *SYNCPAINT                  [expr 0x88] \
			      *SYNCTASK                   [expr 0x89] \
			      *NCMOUSEMOVE                [expr 0xa0] \
			      *NCLBUTTONDOWN              [expr 0xa1] \
			      *NCLBUTTONUP                [expr 0xa2] \
			      *NCLBUTTONDBLCLK            [expr 0xa3] \
			      *NCRBUTTONDOWN              [expr 0xa4] \
			      *NCRBUTTONUP                [expr 0xa5] \
			      *NCRBUTTONDBLCLK            [expr 0xa6] \
			      *NCMBUTTONDOWN              [expr 0xa7] \
			      *NCMBUTTONUP                [expr 0xa8] \
			      *NCMBUTTONDBLCLK            [expr 0xa9] \
			      *NCXBUTTONDOWN              [expr 0xab] \
			      *NCXBUTTONUP                [expr 0xac] \
			      *NCXBUTTONDBLCLK            [expr 0xad] \
			      *KEYDOWN                    [expr 0x100] \
			      *KEYUP                      [expr 0x101] \
			      *CHAR                       [expr 0x102] \
			      *DEADCHAR                   [expr 0x103] \
			      *SYSKEYDOWN                 [expr 0x104] \
			      *SYSKEYUP                   [expr 0x105] \
			      *SYSCHAR                    [expr 0x106] \
			      *SYSDEADCHAR                [expr 0x107] \
			      *KEYFIRST                   [expr 0x100] \
			      *KEYLAST                    [expr 0x108] \
			      *IME_STARTCOMPOSITION       [expr 0x10d] \
			      *IME_ENDCOMPOSITION         [expr 0x10e] \
			      *IME_COMPOSITION            [expr 0x10f] \
			      *IME_KEYLAST                [expr 0x10f] \
			      *INITDIALOG                 [expr 0x110] \
			      *COMMAND                    [expr 0x111] \
			      *SYSCOMMAND                 [expr 0x112] \
			      *TIMER                      [expr 0x113] \
			      *SYSTIMER                   [expr 0x118] \
			      *HSCROLL                    [expr 0x114] \
			      *VSCROLL                    [expr 0x115] \
			      *INITMENU                   [expr 0x116] \
			      *INITMENUPOPUP              [expr 0x117] \
			      *MENUSELECT                 [expr 0x11f] \
			      *MENUCHAR                   [expr 0x120] \
			      *ENTERIDLE                  [expr 0x121] \
			      *MENURBUTTONUP              [expr 0x122] \
			      *MENUDRAG                   [expr 0x123] \
			      *MENUGETOBJECT              [expr 0x124] \
			      *UNINITMENUPOPUP            [expr 0x125] \
			      *MENUCOMMAND                [expr 0x126] \
			      *CHANGEUISTATE              [expr 0x127] \
			      *UPDATEUISTATE              [expr 0x128] \
			      *QUERYUISTATE               [expr 0x129] \
			      *LBTRACKPOINT               [expr 0x131] \
			      *CTLCOLORMSGBOX             [expr 0x132] \
			      *CTLCOLOREDIT               [expr 0x133] \
			      *CTLCOLORLISTBOX            [expr 0x134] \
			      *CTLCOLORBTN                [expr 0x135] \
			      *CTLCOLORDLG                [expr 0x136] \
			      *CTLCOLORSCROLLBAR          [expr 0x137] \
			      *CTLCOLORSTATIC             [expr 0x138] \
			      *MOUSEMOVE                  [expr 0x200] \
			      *LBUTTONDOWN                [expr 0x201] \
			      *LBUTTONUP                  [expr 0x202] \
			      *LBUTTONDBLCLK              [expr 0x203] \
			      *RBUTTONDOWN                [expr 0x204] \
			      *RBUTTONUP                  [expr 0x205] \
			      *RBUTTONDBLCLK              [expr 0x206] \
			      *MBUTTONDOWN                [expr 0x207] \
			      *MBUTTONUP                  [expr 0x208] \
			      *MBUTTONDBLCLK              [expr 0x209] \
			      *MOUSEWHEEL                 [expr 0x20a] \
			      *XBUTTONDOWN                [expr 0x20b] \
			      *XBUTTONUP                  [expr 0x20c] \
			      *XBUTTONDBLCLK              [expr 0x20d] \
			      *MOUSEFIRST                 [expr 0x200] \
			      *MOUSELAST                  [expr 0x20d] \
			      *PARENTNOTIFY               [expr 0x210] \
			      *ENTERMENULOOP              [expr 0x211] \
			      *EXITMENULOOP               [expr 0x212] \
			      *NEXTMENU                   [expr 0x213] \
			      *SIZING                     [expr 0x214] \
			      *CAPTURECHANGED             [expr 0x215] \
			      *MOVING                     [expr 0x216] \
			      *POWERBROADCAST             [expr 0x218] \
			      *DEVICECHANGE               [expr 0x219] \
			      *THEMECHANGED               [expr 0x31a] \
			      *MDICREATE                  [expr 0x220] \
			      *MDIDESTROY                 [expr 0x221] \
			      *MDIACTIVATE                [expr 0x222] \
			      *MDIRESTORE                 [expr 0x223] \
			      *MDINEXT                    [expr 0x224] \
			      *MDIMAXIMIZE                [expr 0x225] \
			      *MDITILE                    [expr 0x226] \
			      *MDICASCADE                 [expr 0x227] \
			      *MDIICONARRANGE             [expr 0x228] \
			      *MDIGETACTIVE               [expr 0x229] \
			      *MDIREFRESHMENU             [expr 0x234] \
			      *DROPOBJECT                 [expr 0x22a] \
			      *QUERYDROPOBJECT            [expr 0x22b] \
			      *BEGINDRAG                  [expr 0x22c] \
			      *DRAGLOOP                   [expr 0x22d] \
			      *DRAGSELECT                 [expr 0x22e] \
			      *DRAGMOVE                   [expr 0x22f] \
			      *MDISETMENU                 [expr 0x230] \
			      *ENTERSIZEMOVE              [expr 0x231] \
			      *EXITSIZEMOVE               [expr 0x232] \
			      *DROPFILES                  [expr 0x233] \
			      *IME_SETCONTEXT             [expr 0x281] \
			      *IME_NOTIFY                 [expr 0x282] \
			      *IME_CONTROL                [expr 0x283] \
			      *IME_COMPOSITIONFULL        [expr 0x284] \
			      *IME_SELECT                 [expr 0x285] \
			      *IME_CHAR                   [expr 0x286] \
			      *IME_REQUEST                [expr 0x288] \
			      *IME_KEYDOWN                [expr 0x290] \
			      *IME_KEYUP                  [expr 0x291] \
			      *CUT                        [expr 0x300] \
			      *COPY                       [expr 0x301] \
			      *PASTE                      [expr 0x302] \
			      *CLEAR                      [expr 0x303] \
			      *UNDO                       [expr 0x304] \
			      *RENDERFORMAT               [expr 0x305] \
			      *RENDERALLFORMATS           [expr 0x306] \
			      *DESTROYCLIPBOARD           [expr 0x307] \
			      *DRAWCLIPBOARD              [expr 0x308] \
			      *PAINTCLIPBOARD             [expr 0x309] \
			      *VSCROLLCLIPBOARD           [expr 0x30a] \
			      *SIZECLIPBOARD              [expr 0x30b] \
			      *ASKCBFORMATNAME            [expr 0x30c] \
			      *CHANGECBCHAIN              [expr 0x30d] \
			      *HSCROLLCLIPBOARD           [expr 0x30e] \
			      *QUERYNEWPALETTE            [expr 0x30f] \
			      *PALETTEISCHANGING          [expr 0x310] \
			      *PALETTECHANGED             [expr 0x311] \
			      *HOTKEY                     [expr 0x312] \
			      *PRINT                      [expr 0x317] \
			      *PRINTCLIENT                [expr 0x318] \
			      *PENWINFIRST                [expr 0x380] \
			      *PENWINLAST                 [expr 0x38f] \
			      *APP                        [expr 0x8000]]]
    return [::winapi::__${fn} $id $msg $wparam $lparam]
}

# ::winapi::SendMessage -- Send messages to window.
#
#	The command sends the specified message to a window or
#	windows. It calls the window procedure for the specified
#	window and does not return until the window procedure has
#	processed the message.
#
# Arguments:
#	w	Handle of window.
#	msg	Message
#	prm1	First parameter of message
#	prm2	Second parameter of message
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winapi::SendMessage { w msg wparam lparam } {
    return [__Message $w $msg $wparam $lparam SendMessage]
}


# ::winapi::PostMessage -- Post messages to window.
#
#	The command posts the specified message to a window or
#	windows. It does not wait for the message to be processed by
#	the window procedure.
#
# Arguments:
#	w	Handle of window.
#	msg	Message
#	prm1	First parameter of message
#	prm2	Second parameter of message
#
# Results:
#	None
#
# Side Effects:
#	None.
proc ::winapi::PostMessage { w msg prm1 prm2 } {
    return [__Message $w $msg $prm1 $prm2 PostMessage]
}

proc ::winapi::PostThreadMessage { tid msg wprm lprm } {
    return [__Message $tid $msg $wprm $lprm PostThreadMessage]
}


proc ::winapi::__init_messages { } {
    variable WINAPI
    variable log
    
    # Local type defs

    # Messages
    core::api __SendMessage \
	{ ::winapi::HWND ::winapi::UINT ::winapi::WPARAM ::winapi::LPARAM } \
	::winapi::LRESULT
    core::api __PostMessage \
	{ ::winapi::HWND ::winapi::UINT ::winapi::WPARAM ::winapi::LPARAM } \
	::winapi::LRESULT
    core::api __PostThreadMessage \
	{ ::winapi::DWORD ::winapi::UINT ::winapi::WPARAM ::winapi::LPARAM } \
	::winapi::LRESULT

    return 1
}

# Now automatically initialises this module, once and only once
# through calling the __init procedure that was just declared above.
::winapi::core::initonce messages ::winapi::__init_messages

package provide winapi 0.2
