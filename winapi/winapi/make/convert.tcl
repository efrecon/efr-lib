# Quick hack to convert lines of C define to lists for the winapi

array set OPTIONS {
    -tabsize       30
    -hexdump       off
}


foreach fname $argv {
    set fd [open $fname]

    while { ! [eof $fd] } {
	set line [string trim [gets $fd]]
	if { $line ne "" } {
	    if { [regexp "^\#\\s*define" $line] } {
		set idx [string first "define" $line]
		incr idx [string length "define"]
		set remaining [string trim [string range $line $idx end]]
		set constant [lindex $remaining 0]
		set value [lindex $remaining 1]

		puts -nonewline "$constant"
		for { set i [string length $constant] } \
		    { $i < $OPTIONS(-tabsize) } {incr i} {
			puts -nonewline " "
		    }
		if { [string is true $OPTIONS(-hexdump)] } {
		    puts "\[expr [format 0x%x [expr $value]]\] \\"
		} else {
		    puts "[expr $value] \\"
		}
	    }
	}
    }
    close $fd
}
