## Make-like replacement from http://wiki.tcl.tk/9293
proc file.newer? {f _than_ f2} {
    if {![file exists $f] || ![file exists $f2]} {
	return 1
    }
    if {[file mtime $f] > [file mtime $f2]} {
	return 1
    }
    return 0
}

proc is.file? f {
    return [file isfile $f]
}

proc is.target? t {
    return [info exists ::targetAr($t)]
}

array set ::targetAr {}

proc make.force {t _from_ fromList _using_ body} {
    set ::targetAr($t) [list $fromList $body]
    interp alias {} $t {} make.target $t 1
}

proc make {t _from_ fromList _using_ body} {
    set ::targetAr($t) [list $fromList $body]
    interp alias {} $t {} make.target $t
}

proc make.target {t {force 0}} {
    if {[is.target? $t]} {
	foreach {fromList body} [set ::targetAr($t)] break

	set build 0
	foreach f $fromList {
	    if {[is.target? $f]} {
		set r [make.target $f]
		if {[is.file? $f] && [file.newer? $f than $t]} {
		    set build 1
		} elseif {$r} {
		    set build 1
		}
	    } elseif {[is.file? $f]} {
		if {!$build} {
		    set build [file.newer? $f than $t]
		}
	    } else {
		return -code error "$f isn't a target or existing source"
	    }
	}
	if {$build || $force} {
	    uplevel #0 $body
	    return 1
	}
	return 0
    } else {
	return -code error "make.target called with an invalid target: $t"
    }
}

proc mexec.old args {
    set cmd [join $args]
    puts $cmd
    catch {eval exec -- $cmd} msg
    if {[string length $msg]} {
	puts $msg
    }
}

proc mexec args {
    puts $args
    catch {eval exec -- $args} msg
    if {[string length $msg]} {
	puts $msg
    }
}


