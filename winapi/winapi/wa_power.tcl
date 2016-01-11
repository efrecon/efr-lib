package require winapi::core

namespace eval ::winapi {
    variable WINAPI
    variable log

}

proc ::winapi::GetSystemPowerStatus { } {
    set len [::ffidl::info sizeof ::winapi::SYSTEM_POWER_STATUS]
    set buf [binary format "x${len}"]
    if { [__GetSystemPowerStatus buf] } {
	array set res {}
	binary scan $buf [::ffidl::info format ::winapi::SYSTEM_POWER_STATUS] \
	    res(ACLineStatus) \
	    res(BatteryFlag) \
	    res(BatteryLifePercent) \
	    res(Reserved1) \
	    res(BatteryLifeTime) \
	    res(BatteryFullLifeTime)
	set res(BatteryFlag) [core::tflags $res(BatteryFlag) \
				  [list \
				       BATTERY_FLAG_HIGH       1 \
				       BATTERY_FLAG_LOW        2 \
				       BATTERY_FLAG_CRITICAL   4 \
				       BATTERY_FLAG_CHARGING   8 \
				       BATTERY_FLAG_NO_BATTERY 128 \
				       BATTERY_FLAG_UNKNOWN    255]]
	return [array get res]
    }
    return ""
}

proc ::winapi::__init_power {} {
    variable WINAPI
    variable log

    #Typedefs
    ::ffidl::typedef ::winapi::SYSTEM_POWER_STATUS \
	::winapi::BYTE ::winapi::BYTE ::winapi::BYTE ::winapi::BYTE \
	::winapi::DWORD ::winapi::DWORD

    # Power management functions.
    core::api __GetSystemPowerStatus { pointer-var } ::winapi::BOOL

    return 1
}


# Now automatically initialises this module, once and only once
# through calling the __init procedure that was just declared above.
::winapi::core::initonce power ::winapi::__init_power

package provide winapi 0.2
