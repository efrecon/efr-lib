package require winapi::core

namespace eval ::winapi {
    variable WINAPI
    variable log
}


# ::winapi::mixerOpen -- Opens a mixer device
#
#	This procedure opens a specified mixer device and ensures that
#	the device will not be removed until the application closes
#	the handle
#
# Arguments:
#	id	Identifier of mixer to open
#	flags	Flags for opening the device.
#
# Results:
#	Return a handle to the mixer
#
# Side Effects:
#	None.
proc ::winapi::mixerOpen { id { flags 0 } } {
    variable WINAPI
    variable log

    set buf [binary format "i" 0]
    set flags [core::flags $flags [list \
				   "*AUX"           [expr {0x50000000}] \
				   "*HMIDIIN"       [expr {0xC0000000}] \
				   "*HMIDIOUT"      [expr {0xB0000000}] \
				   "*HMIXER"        [expr {0x80000000}] \
				   "*HWAVEIN"       [expr {0xA0000000}] \
				   "*HWAVEOUT"      [expr {0x90000000}] \
				   "*MIDIIN"        [expr {0x40000000}] \
				   "*MIDIOUT"       [expr {0x30000000}] \
				   "*MIXER"         0 \
				   "*WAVEIN"        [expr {0x20000000}] \
				   "*WAVEOUT"       [expr {0x10000000}]]]
    set res [::winapi::__mixerOpen buf $id 0 0 $flags]
    if { $res == 0 } {
	binary scan $buf "i" mixer
	return $mixer
    } else {
	return ""
    }
}



# ::winapi::mixerGetLineInfo -- Get mixer line info
#
#	This procedure retrieves information about a specific line of
#	a mixer device.  This procedure is highly untested and is
#	likely to fail when getting some sort of information.
#
# Arguments:
#	mixer	Handle of mixer
#	flags	Flags for retrieving information about an audio line
#	args	List of key vals for initialsing the MIXERLINE structure
#
# Results:
#	Return a list ready for an array set command (empty on error).
#	This list represent the content of the MIXERLINE that was got.
#
# Side Effects:
#	None.
proc ::winapi::mixerGetLineInfo { mixer flags args } {
    variable WINAPI
    variable log

    # Initialise the structure with default "null" values.
    set init(cbStruct) [::ffidl::info sizeof ::winapi::MIXERLINE]
    foreach idx [list dwDestination dwSource dwLineID fdwLine dwUser \
		     dwComponentType cChannels cConnections cControls \
		     dwType dwDeviceID wMid wPid vDriverVersion] {
	set init($idx) 0
    }
    foreach idx [list szShortName szName szPname] {
	set init($idx) ""
    }

    # Now take in additional input parameters, and convert textual
    # constants to integers if necessary.
    array set init $args
    set init(dwComponentType) \
	[core::flag $init(dwComponentType) \
	     [list \
		  "*DST_UNDEFINED" 0 \
		  "*DST_DIGITAL" 1\
		  "*DST_LINE" 2\
		  "*DST_MONITOR" 3\
		  "*DST_SPEAKERS" 4\
		  "*DST_HEADPHONES" 5\
		  "*DST_TELEPHONE" 6\
		  "*DST_WAVEIN" 7\
		  "*DST_VOICEIN" 8\
		  "*SRC_UNDEFINED" [expr {0x1000}] \
		  "*SRC_DIGITAL" [expr {0x1000+1}] \
		  "*SRC_LINE" [expr {0x1000+2}] \
		  "*SRC_MICROPHONE" [expr {0x1000+3}] \
		  "*SRC_SYNTHESIZER" [expr {0x1000+4}] \
		  "*SRC_COMPACTDISC" [expr {0x1000+5}] \
		  "*SRC_TELEPHONE" [expr {0x1000+6}] \
		  "*SRC_PCSPEAKER" [expr {0x1000+7}] \
		  "*SRC_WAVEOUT" [expr {0x1000+8}] \
		  "*SRC_AUXILIARY" [expr {0x1000+9}] \
		  "*SRC_ANALOG" [expr {0x1000+10}]]]
    
    set flags [core::flags $flags [list \
				   "*COMPONENTTYPE" 3 \
				   "*DESTINATION"   0 \
				   "*LINEID"        2 \
				   "*SOURCE"        1 \
				   "*TARGETTYPE"    4 \
				   "*AUX"           [expr {0x50000000}] \
				   "*HMIDIIN"       [expr {0xC0000000}] \
				   "*HMIDIOUT"      [expr {0xB0000000}] \
				   "*HMIXER"        [expr {0x80000000}] \
				   "*HWAVEIN"       [expr {0xA0000000}] \
				   "*HWAVEOUT"      [expr {0x90000000}] \
				   "*MIDIIN"        [expr {0x40000000}] \
				   "*MIDIOUT"       [expr {0x30000000}] \
				   "*MIXER"         0 \
				   "*WAVEIN"        [expr {0x20000000}] \
				   "*WAVEOUT"       [expr {0x10000000}]]]

    # We are ready, fill in a temporary buffer with all input and
    # default values and call the low-level windows function with all
    # the parameters.
    set buf [binary format "iiiiiiiiiia16a64iissia32" \
		 $init(cbStruct) $init(dwDestination) $init(dwSource) \
		 $init(dwLineID) $init(fdwLine) $init(dwUser) \
		 $init(dwComponentType) $init(cChannels) $init(cConnections) \
		 $init(cControls) $init(szShortName) $init(szName) \
		 $init(dwType) $init(dwDeviceID) $init(wMid) $init(wPid) \
		 $init(vDriverVersion) $init(szPname)]
    set r [::winapi::__mixerGetLineInfo $mixer buf $flags]

    # Analyse the result
    if { $r == 0 } {
	# We managed to do the call, convert back integer constants to
	# string constants and return a list ready for an array set
	# call.
	array set res {}
	binary scan $buf "iiiiiiiiiia16a64iissia32" \
	    res(cbStruct) res(dwDestination) res(dwSource) \
	    res(dwLineID) res(fdwLine) res(dwUser) \
	    res(dwComponentType) res(cChannels) res(cConnections) \
	    res(cControls) res(szShortName) res(szName) \
	    res(dwType) res(dwDeviceID) res(wMid) res(wPid) \
	    res(vDriverVersion) res(szPname)
	set res(fdwLine) \
	    [core::tflag $res(fdwLine) \
		 [list \
		      "MIXERLINE_LINEF_ACTIVE" 1 \
		      "MIXERLINE_LINEF_DISCONNECTED" [expr {0x8000}] \
		      "MIXERLINE_LINEF_SOURCE" [expr {0x80000000}]]]
	set res(dwComponentType) \
	    [core::tflag $res(dwComponentType) \
		 [list \
		      "MIXERLINE_COMPONENTTYPE_DST_UNDEFINED" 0 \
		      "MIXERLINE_COMPONENTTYPE_DST_DIGITAL" 1\
		      "MIXERLINE_COMPONENTTYPE_DST_LINE" 2\
		      "MIXERLINE_COMPONENTTYPE_DST_MONITOR" 3\
		      "MIXERLINE_COMPONENTTYPE_DST_SPEAKERS" 4\
		      "MIXERLINE_COMPONENTTYPE_DST_HEADPHONES" 5\
		      "MIXERLINE_COMPONENTTYPE_DST_TELEPHONE" 6\
		      "MIXERLINE_COMPONENTTYPE_DST_WAVEIN" 7\
		      "MIXERLINE_COMPONENTTYPE_DST_VOICEIN" 8\
		      "MIXERLINE_COMPONENTTYPE_SRC_UNDEFINED" [expr {0x1000}] \
		      "MIXERLINE_COMPONENTTYPE_SRC_DIGITAL" [expr {0x1000+1}] \
		      "MIXERLINE_COMPONENTTYPE_SRC_LINE" [expr {0x1000+2}] \
		      "MIXERLINE_COMPONENTTYPE_SRC_MICROPHONE" [expr {0x1000+3}] \
		      "MIXERLINE_COMPONENTTYPE_SRC_SYNTHESIZER" [expr {0x1000+4}] \
		      "MIXERLINE_COMPONENTTYPE_SRC_COMPACTDISC" [expr {0x1000+5}] \
		      "MIXERLINE_COMPONENTTYPE_SRC_TELEPHONE" [expr {0x1000+6}] \
		      "MIXERLINE_COMPONENTTYPE_SRC_PCSPEAKER" [expr {0x1000+7}] \
		      "MIXERLINE_COMPONENTTYPE_SRC_WAVEOUT" [expr {0x1000+8}] \
		      "MIXERLINE_COMPONENTTYPE_SRC_AUXILIARY" [expr {0x1000+9}] \
		      "MIXERLINE_COMPONENTTYPE_SRC_ANALOG" [expr {0x1000+10}]]]
	set res(dwType) \
	    [core::tflag $res(dwType) \
		 [list \
		      "MIXERLINE_TARGETTYPE_UNDEFINED" 0 \
		      "MIXERLINE_TARGETTYPE_WAVEOUT" 1 \
		      "MIXERLINE_TARGETTYPE_WAVEIN" 2 \
		      "MIXERLINE_TARGETTYPE_MIDIOUT" 3 \
		      "MIXERLINE_TARGETTYPE_MIDIIN" 4 \
		      "MIXERLINE_TARGETTYPE_AUX" 5]]
	return [array get res]
    } else {
	${log}::warn "Error when executing mixerGetlineInfo: $r"
	return [list]
    }
}



# ::winapi::mixerGetLineControls -- Get line controls
#
#	This procedure retrieves one or more controls associated with
#	an audio line.  This procedure is highly untested and is
#	likely to fail when getting some sort of information, in
#	particular it only supports getting one MIXERCONTROL (as
#	opposed to arrays!).
#
# Arguments:
#	mixer	Handle of mixer
#	flags	Flags for retrieving information about an audio line
#	args	List of key vals for initialsing the MIXERLINECONTROLS struct
#
# Results:
#	Return a list ready for an array set command (empty on error).
#	This list represent the content of the MIXERCONTROL structure
#	that was got.
#
# Side Effects:
#	None.
proc ::winapi::mixerGetLineControls { mixer flags args } {
    variable WINAPI
    variable log

    # Initialise the structure with default "null" values, we directly
    # allocate memory for the control reception buffer.
    set ptr [::ffidl::malloc [::ffidl::info sizeof ::winapi::MIXERCONTROL]]
    set init(cbStruct) [::ffidl::info sizeof ::winapi::MIXERLINECONTROLS]
    set init(cControls) 1
    set init(cbmxctrl) [::ffidl::info sizeof ::winapi::MIXERCONTROL]
    set init(pamxctrl) $ptr
    foreach idx [list dwLineID dwControl] {
	set init($idx) 0
    }

    # Now take in additional input parameters, and convert textual
    # constants to integers if necessary.
    array set init $args
    set flags [core::flags $flags [list \
				   "*ALL"           0 \
				   "*ONEBYID"       1 \
				   "*ONEBYTYPE"     2 \
				   "*AUX"           [expr {0x50000000}] \
				   "*HMIDIIN"       [expr {0xC0000000}] \
				   "*HMIDIOUT"      [expr {0xB0000000}] \
				   "*HMIXER"        [expr {0x80000000}] \
				   "*HWAVEIN"       [expr {0xA0000000}] \
				   "*HWAVEOUT"      [expr {0x90000000}] \
				   "*MIDIIN"        [expr {0x40000000}] \
				   "*MIDIOUT"       [expr {0x30000000}] \
				   "*MIXER"         0 \
				   "*WAVEIN"        [expr {0x20000000}] \
				   "*WAVEOUT"       [expr {0x10000000}]]]
    if { $flags == 2 } {
	set init(dwControl) \
	    [core::flag $init(dwControl) \
		 [list \
		      "*CUSTOM"       [expr {0x0}] \
		      "*BOOLEANMETER" [expr {0x10010000}] \
		      "*SIGNEDMETER"  [expr {0x10020000}] \
		      "*PEAKMETER"    [expr {0x10020001}] \
		      "*UNSIGNEDMETER"        [expr {0x10030000}] \
		      "*BOOLEAN"      [expr {0x20010000}] \
		      "*ONOFF"        [expr {0x20010001}] \
		      "*MUTE" [expr {0x20010002}] \
		      "*MONO" [expr {0x20010003}] \
		      "*LOUDNESS"     [expr {0x20010004}] \
		      "*STEREOENH"    [expr {0x20010005}] \
		      "*BUTTON"       [expr {0x21010000}] \
		      "*DECIBELS"     [expr {0x30040000}] \
		      "*SIGNED"       [expr {0x30020000}] \
		      "*UNSIGNED"     [expr {0x30030000}] \
		      "*PERCENT"      [expr {0x30050000}] \
		      "*SLIDER"       [expr {0x40020000}] \
		      "*PAN"  [expr {0x40020001}] \
		      "*QSOUNDPAN"    [expr {0x40020002}] \
		      "*FADER"        [expr {0x50030000}] \
		      "*VOLUME"       [expr {0x50030001}] \
		      "*BASS" [expr {0x50030002}] \
		      "*TREBLE"       [expr {0x50030003}] \
		      "*EQUALIZER"    [expr {0x50030004}] \
		      "*SINGLESELECT" [expr {0x70010000}] \
		      "*MUX"  [expr {0x70010001}] \
		      "*MULTIPLESELECT"       [expr {0x71010000}] \
		      "*MIXER"        [expr {0x71010001}] \
		      "*MICROTIME"    [expr {0x60030000}] \
		      "*MILLITIME"    [expr {0x61030000}]]]
    }

    # We are ready, fill in a temporary buffer with all input and
    # default values and call the low-level windows function with all
    # the parameters.
    set buf [binary format "iiiiii" \
		 $init(cbStruct) $init(dwLineID) $init(dwControl) \
		 $init(cControls) $init(cbmxctrl) $init(pamxctrl)]
    set r [::winapi::__mixerGetLineControls $mixer buf $flags]

    # Analyse the result
    if { $r == 0 } {
	# We managed to do the call, convert back integer constants to
	# string constants and return a list ready for an array set
	# call.
	array set res {}
	set ctlbuf [::ffidl::peek $ptr \
			[::ffidl::info sizeof ::winapi::MIXERCONTROL]]
	::ffidl::free $ptr
	binary scan $ctlbuf "iiiiia16a64ii" \
	    res(cbStruct) res(dwControlID) res(dwControlType) \
	    res(fdwControl) res(cMultipleItems) \
	    res(szShortName) res(szName) \
	    res(lMinimum) res(lMaximum)
	set res(fdwControl) \
	    [core::tflag $res(fdwControl) \
		 [list \
		      "MIXERCONTROL_CONTROLF_DISABLED" [expr {0x80000000}] \
		      "MIXERCONTROL_CONTROLF_UNIFORM" 1 \
		      "MIXERCONTROL_CONTROLF_MULTIPLE" 2]]
	set res(dwControlType) \
	    [core::tflag $res(dwControlType) \
		 [list \
		      "MIXERCONTROL_CONTROLTYPE_CUSTOM"       [expr {0x0}] \
		      "MIXERCONTROL_CONTROLTYPE_BOOLEANMETER" [expr {0x10010000}] \
		      "MIXERCONTROL_CONTROLTYPE_SIGNEDMETER"  [expr {0x10020000}] \
		      "MIXERCONTROL_CONTROLTYPE_PEAKMETER"    [expr {0x10020001}] \
		      "MIXERCONTROL_CONTROLTYPE_UNSIGNEDMETER"        [expr {0x10030000}] \
		      "MIXERCONTROL_CONTROLTYPE_BOOLEAN"      [expr {0x20010000}] \
		      "MIXERCONTROL_CONTROLTYPE_ONOFF"        [expr {0x20010001}] \
		      "MIXERCONTROL_CONTROLTYPE_MUTE" [expr {0x20010002}] \
		      "MIXERCONTROL_CONTROLTYPE_MONO" [expr {0x20010003}] \
		      "MIXERCONTROL_CONTROLTYPE_LOUDNESS"     [expr {0x20010004}] \
		      "MIXERCONTROL_CONTROLTYPE_STEREOENH"    [expr {0x20010005}] \
		      "MIXERCONTROL_CONTROLTYPE_BUTTON"       [expr {0x21010000}] \
		      "MIXERCONTROL_CONTROLTYPE_DECIBELS"     [expr {0x30040000}] \
		      "MIXERCONTROL_CONTROLTYPE_SIGNED"       [expr {0x30020000}] \
		      "MIXERCONTROL_CONTROLTYPE_UNSIGNED"     [expr {0x30030000}] \
		      "MIXERCONTROL_CONTROLTYPE_PERCENT"      [expr {0x30050000}] \
		      "MIXERCONTROL_CONTROLTYPE_SLIDER"       [expr {0x40020000}] \
		      "MIXERCONTROL_CONTROLTYPE_PAN"  [expr {0x40020001}] \
		      "MIXERCONTROL_CONTROLTYPE_QSOUNDPAN"    [expr {0x40020002}] \
		      "MIXERCONTROL_CONTROLTYPE_FADER"        [expr {0x50030000}] \
		      "MIXERCONTROL_CONTROLTYPE_VOLUME"       [expr {0x50030001}] \
		      "MIXERCONTROL_CONTROLTYPE_BASS" [expr {0x50030002}] \
		      "MIXERCONTROL_CONTROLTYPE_TREBLE"       [expr {0x50030003}] \
		      "MIXERCONTROL_CONTROLTYPE_EQUALIZER"    [expr {0x50030004}] \
		      "MIXERCONTROL_CONTROLTYPE_SINGLESELECT" [expr {0x70010000}] \
		      "MIXERCONTROL_CONTROLTYPE_MUX"  [expr {0x70010001}] \
		      "MIXERCONTROL_CONTROLTYPE_MULTIPLESELECT"       [expr {0x71010000}] \
		      "MIXERCONTROL_CONTROLTYPE_MIXER"        [expr {0x71010001}] \
		      "MIXERCONTROL_CONTROLTYPE_MICROTIME"    [expr {0x60030000}] \
		      "MIXERCONTROL_CONTROLTYPE_MILLITIME"    [expr {0x61030000}]]]

	return [array get res]
    } else {
	${log}::warn "Error when executing mixerGetLineControls: $r"
	return [list]
    }
}


# ::winapi::mixerGetControlDetails -- Get line controls details
#
#	This procedure retrieves details about a single control
#	associated with an audio line.  This procedure is highly
#	untested and is likely to fail when getting some sort of
#	information, in particular it only supports getting of
#	boolean, signed and unsigned details.
#
# Arguments:
#	mixer	Handle of mixer
#	flags	Flags for retrieving information about an audio line
#	args	List of key vals for initialsing the MIXERCONTROLDETAILS struct
#
# Results:
#	Return the current value of the control or an empty string on
#	errors.
#
# Side Effects:
#	None.
proc ::winapi::mixerGetControlDetails { mixer flags args } {
    variable WINAPI
    variable log

    # Initialise the structure with default "null" values, we directly
    # allocate memory for the control reception buffer.
    set ptr [::ffidl::malloc [::ffidl::info sizeof int]]
    set init(cbStruct) [::ffidl::info sizeof ::winapi::MIXERCONTROLDETAILS]
    set init(cbDetails) [::ffidl::info sizeof int]
    set init(paDetails) $ptr
    foreach idx [list dwControlID cChannels hwndOwner] {
	set init($idx) 0
    }

    # Now take in additional input parameters, and convert textual
    # constants to integers if necessary.
    array set init $args
    set flags [core::flags $flags [list \
				   "*VALUE"           0 \
				   "*LISTTEXT"        1 \
				   "*AUX"           [expr {0x50000000}] \
				   "*HMIDIIN"       [expr {0xC0000000}] \
				   "*HMIDIOUT"      [expr {0xB0000000}] \
				   "*HMIXER"        [expr {0x80000000}] \
				   "*HWAVEIN"       [expr {0xA0000000}] \
				   "*HWAVEOUT"      [expr {0x90000000}] \
				   "*MIDIIN"        [expr {0x40000000}] \
				   "*MIDIOUT"       [expr {0x30000000}] \
				   "*MIXER"         0 \
				   "*WAVEIN"        [expr {0x20000000}] \
				   "*WAVEOUT"       [expr {0x10000000}]]]

    # We are ready, fill in a temporary buffer with all input and
    # default values and call the low-level windows function with all
    # the parameters.
    set buf [binary format "iiiiii" \
		 $init(cbStruct) $init(dwControlID) $init(cChannels) \
		 $init(hwndOwner) $init(cbDetails) $init(paDetails)]
    set r [::winapi::__mixerGetControlDetails $mixer buf $flags]

    # Analyse the result
    if { $r == 0 } {
	# We managed to do the call, convert back integer constants to
	# string constants and return a list ready for an array set
	# call.
	array set res {}
	set detbuf [::ffidl::peek $ptr [::ffidl::info sizeof int]]
	::ffidl::free $ptr
	binary scan $detbuf "i" details
	return $details
    } else {
	${log}::warn "Error when executing mixerGetLineControls: $r"
	return ""
    }
}


proc ::winapi::__init_mixer { } {
    variable WINAPI
    variable log

    # Local types
    eval ::ffidl::typedef ::winapi::__MIXER_SHORT_NAME \
	[::winapi::core::strrepeat char 16 " "]
    eval ::ffidl::typedef ::winapi::__MIXER_LONG_NAME \
	[::winapi::core::strrepeat char 64 " "]
    eval ::ffidl::typedef ::winapi::__PNAME \
	[::winapi::core::strrepeat char 32 " "]
    ::ffidl::typedef ::winapi::MIXERLINE uint32 uint32 uint32 uint32 \
	uint32 uint32 uint32 uint32 uint32 uint32 \
	::winapi::__MIXER_SHORT_NAME ::winapi::__MIXER_LONG_NAME \
	uint32 uint32 uint16 uint16 uint32 ::winapi::__PNAME
    ::ffidl::typedef ::winapi::MIXERLINECONTROLS uint32 uint32 uint32 uint32 \
	uint32 uint32
    ::ffidl::typedef ::winapi::MIXERCONTROL uint32 uint32 uint32 uint32 \
	uint32 ::winapi::__MIXER_SHORT_NAME ::winapi::__MIXER_LONG_NAME \
	uint32 uint32 uint32 uint32 uint32 uint32 \
	uint32 uint32 uint32 uint32 uint32 uint32
    ::ffidl::typedef ::winapi::MIXERCONTROLDETAILS \
	uint32 uint32 uint32 uint32 uint32 uint32

    # Mixers
    core::api __mixerOpen { pointer-var uint32 uint32 uint32 uint32 } int
    core::api __mixerGetLineInfo { pointer pointer-var uint32 } int
    core::api __mixerGetLineControls { pointer pointer-var uint32 } int
    core::api __mixerGetControlDetails { pointer pointer-var uint32 } int
    core::api mixerClose { pointer } int

    return 1
}

# Now automatically initialises this module, once and only once
# through calling the __init procedure that was just declared above.
if { [catch {package require Ffidlrt} ver] == 0 } {
    ::winapi::core::initonce mixer ::winapi::__init_mixer
}

package provide winapi 0.2
