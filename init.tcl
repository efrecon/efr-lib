##################
## Module Name     --  init
## Original Author --  Emmanuel Fr�con - emmanuel.frecon@myjoice.com
## Description:
##
##    This module implements a "generic" program starter that will
##    forcefully take a number of options and initialise a number of
##    packages from the til and from other common locations.  The
##    module has grown from repeatedly writing more or less the same
##    quickstarter for all programs, thus in order to cut down the
##    amount of work to write properly behaved programs.
##
##################

namespace eval ::init {
    variable INIT
    if { ! [info exists INIT] } {
        array set INIT {
            idgene       0
            -argsread    ""
            -booleans    {}
            -depends     {til progver}
            -load        {uobj}
            -log         ""
            -language    "en"
            -messages    "msgs"
            -options     {}
            -outlog      ""
            -packages    {progver}
            -parsed      ""
            -loaded      ""
            -progress    0
            -quiet       {}
            -sources     {}
            -store       ""
            -splash      ""
            -callback    ""
            -extensions  {tcl tk}
            argv0        ""
            argv         ""
            argv_copied  0
            inits        {}
            src_locs     {. "./sources/%progname%" "./modules/%progname%" "./src/%progname%" "./sources" "./modules" "./src"}
        }
        variable forced_opts {
            { verbose.alpha "warn" "Verbosity level" }
            { config.arg "%progdir%/%progname%.factory.cfg %progdir%/%progname%.%platform%.factory.cfg %progdir%/%progname%.local.cfg %progdir%/%progname%.%platform%.local.cfg %progdir%/%progname%.cfg %progdir%/%progname%.%platform%.cfg" "Configuration files" }
            { arguments.arg "%progdir%/%progname%.factory.arg %progdir%/%progname%.%platform%.factory.arg %progdir%/%progname%.local.arg %progdir%/%progname%.%platform%.local.arg %progdir%/%progname%.arg %progdir%/%progname%.%platform%.arg" "Configuration files for overriding command line arguments" }
            { language.arg "" "Language to use in app, empty for OS language" }
        }
        variable libdir [file dirname [file normalize [info script]]]
    }
}


# ::init::__clean_progname -- Clean running program name
#
#       This procedure cleans the name of the running program (using
#       the main script name) in order to be able to use that name for
#       initialising variables or similar.
#
# Results:
#       Return a clean name
#
# Side Effects:
#       None.
proc ::init::__clean_progname {} {
    global argv0
    
    set name [file rootname [file tail $argv0]]
    set name [regsub -all \\W $name ""]
    
    return $name
}


# ::init::topdir -- Real top directory
#
#       Return the top directory where the running script is
#       positioned, this procedure is aware of starkit packaging and,
#       in that case, does not return a directory which is inside the
#       starkit, but rather real directory where the .exe or .kit are
#       positioned.
#
# Results:
#       Return the real directory where program is.
#
# Side Effects:
#       None.
proc ::init::topdir {} {
    # Agnostic topdirectory
    if { [info exists ::starkit::topdir] } {
        set topdir $::starkit::topdir
    } else {
        set topdir [file dirname [info script]]
    }
}



# ::init::main -- Path to application (as from OS)
#
#       This procedure will either return the name of the application
#       as seen from the user (i.e. the packed starkit, i.e. the .exe)
#       or the path of the main file.
#
# Results:
#       Return the fully normalize path to the main application script
#       or executable.
#
# Side Effects:
#       None.
proc ::init::main {} {
    if { [info exists ::starkit::topdir] } {
        return [info nameofexecutable]
    } else {
        return [file normalize $::argv0]
    }
}



# ::init::__localisation -- Access translation messages
#
#       This procedure decides upon the language to use for the
#       application (either overriden via the argument, either guessed
#       from system settigns) and arrange to access messages from
#       proper directories.
#
# Arguments:
#       applang	Language for application to force
#
# Results:
#       Return the language chosen for the application
#
# Side Effects:
#       Load the messages from the -messages directories inside or
#       outside the starkit (or outside only when not relevant).
proc ::init::__localisation { { applang "" } } {
    variable INIT
    
    set ver [package require msgcat]
    uplevel \#0 namespace import ::msgcat::mc
    
    # Set default locale, then try to get from environment or (in
    # Windows) registry
    ::msgcat::mclocale $INIT(-language)
    
    if { [info exists ::env(LANG)] } {
        ::msgcat::mclocale $::env(LANG)
    } else {
        if {[string match -nocase Windows* $::tcl_platform(os)] \
                    && ![catch {package require registry}]} {
            # XXX: Note that Windows 7 seems to have a property called
            # LocaleName which should be compliant with the msgcat
            # system. On my swedish system, the locale is "sv-SE" as
            # expected.
            if {![catch {registry get {HKEY_CURRENT_USER\Control Panel\International} sLanguage} res]} {
                set lang [string tolower [string range $res 0 1]]
                ::msgcat::mclocale $lang
            }
        }
    }
    
    # Now set default if we had set the language manually, i.e. if we
    # have overwritten all defaults.
    if { $applang ne "" } {
        ::msgcat::mclocale $applang
    }
    
    # Arrange for having the message directory outside or inside a starkit
    if { [info exists ::starkit::topdir] } {
        set dirs [list $::starkit::topdir [file dirname $::starkit::topdir]]
    } else {
        set dirs [list [file dirname $::argv0]]
    }
    
    # Now load messages and default to the default language if we failed.
    set loaded 0
    foreach d $dirs {
        if { [file isdirectory $d] } {
            if {[::msgcat::mcload [file join $d $INIT(-messages)]]} {
                set loaded 1
                break
            }
        }
    }
    if { ! $loaded } {
        # Revert to default application language, i.e. probably english!
        ::msgcat::mclocale $INIT(-language)
        ::msgcat::mcload [file join $d $INIT(-messages)]
    }
    
    return [::msgcat::mclocale]
}


# ::init::argv -- Return the arguments that were passed to this application
#
#       This procedure will return the arguments that were used to
#       start this application.  Since argument parsing destroys the
#       argument list, this procedure arranges to return our local
#       copy of the arguments whenever necessary.
#
# Arguments:
#       None.
#
# Results:
#       Return the list of arguments passed on the command line.
#
# Side Effects:
#       None.
proc ::init::argv {} {
    global argv0
    global argv
    variable INIT
    
    if { $INIT(argv_copied) } {
        return $INIT(argv)
    } else {
        return $argv
    }
}


# ::init::log -- Logging output to the best of our possibilities.
#
#       This procedure will attempt to log through the log module that
#       is registered during the main initialisation and that is
#       global to the program.  If not possible, it will pass through
#       the message to the bootstrapping library log, if present.  In
#       other cases, the log message will be lost.
#
# Arguments:
#	lvl	Level of the log message.
#	msg	Message to log
#
# Results:
#       Return 1 if the message could be logged, 0 otherwise.
#
# Side Effects:
#       None.
proc ::init::log { lvl msg } {
    variable INIT
    
    # Access global array containing options.
    upvar \#0 [lindex $INIT(inits) end] ARGS
    set output 0
    if { [info exists ARGS(-store)] } {
        upvar \#0 $ARGS(-store) GLBL
        if { [info exists GLBL(log)] } {
            $GLBL(log)::$lvl $msg
            set output 1
        }
    }
    
    if { !$output && [info commands ::bootstrap::log] ne "" } {
        ::bootstrap::log $lvl $msg
        return 1
    }
    
    return $output
}


# ::init::arguments -- Override command-line arguments with file contents
#
#       Read the content of the files that are pointed at by the
#       arguments command line option and override the content of the
#       command line options. While this feels awkward at first, it
#       allows automated installations that easily write a number of
#       options to one or several files, letting an application
#       picking up its defaults to a number of known locations.
#
# Arguments:
#	-- none -- Takes value from latest inited application
#
# Results:
#       Return the list of file paths containing command line options
#       that were successfully read and parsed.
#
# Side Effects:
#       Reinitialise application verbosity level since this might be
#       one of the options that was modified
proc ::init::arguments { } {
    variable INIT
    variable libdir
    
    # Access global array containing options.
    upvar \#0 [lindex $INIT(inits) end] ARGS
    upvar \#0 $ARGS(-store) GLBL
    
    # Read arguments from file if any, adapt verbosity if necessary
    set argfiles {}
    foreach fname $GLBL(arguments) {
        set arg_fname [::diskutil::fname_resolv $fname]
        if { [file exists $arg_fname] } {
            log notice \
                    "Overriding program arguments with content of $arg_fname"
            if { [catch {::uobj::deserialize GLBL $arg_fname \
                        [::argutil::options $ARGS(-options)]} \
                        argset] == 0 } {
                if { [lsearch $argset "verbose"] >= 0 } {
                    log warn "Fixing log level to $GLBL(verbose)"
                    foreach m $ARGS(-load) {
                        ${m}::loglevel $GLBL(verbose)
                    }
                    $GLBL(log)::setlevel $GLBL(verbose)
                }
                # Fix booleans
                foreach b $ARGS(-booleans) {
                    if { [lsearch $argset $b] >= 0 } {
                        ::argutil::boolean GLBL [string trimleft $b "-"]
                    }
                }
                lappend argfiles $fname
            } else {
                log warn "Error when reading arguments: $argset"
            }
        }
    }
    return $argfiles
}


# ::init::configuration -- Read configuration for modules
#
#       Read the configuration files for module-specific
#       configuration.  The configuration files are listed under the
#       config index of the global array containing application state.
#
# Arguments:
#	glbl_p	"Pointer" to global array containing application state.
#               If empty, will pick it from latest inited application.
#
# Results:
#       Return the list of file paths that were read and considered
#       for module configuration, in their order of reading.
#
# Side Effects:
#       Actively modify defaults for module using their defaults
#       procedures
proc ::init::configuration { { glbl_p "" } } {
    variable INIT
    
    # Access global array containing options.
    if { $glbl_p eq "" } {
        upvar \#0 [lindex $INIT(inits) end] ARGS
        upvar \#0 $ARGS(-store) GLBL
    } else {
        upvar $glbl_p GLBL
    }
    
    # Read configuration files for module-based settings
    set configs {}
    log debug "Read modules configuration from config files"
    foreach fname $GLBL(config) {
        set fname [::diskutil::fname_resolv $fname]
        if { [file exists $fname] } {
            log notice "Reading options from $fname"
            ::uobj::readconfig $fname
            lappend configs $fname
        }
    }
    
    return $configs
}


# ::init::dependencies -- Arrange for library access
#
#       Arrange to access libraries that this application depends on.
#       Accessing the libraries is a mix of modifying the auto_path,
#       but also copying libraries that contain dynamic libraries
#       outside of starpacks so that they can be loaded by the
#       operating system.
#
# Arguments:
#	-- none -- Takes value from latest inited application
#
# Results:
#       None.
#
# Side Effects:
#       Modifies auto_path and copied to temporary location on disk,
#       see ::argutil::accesslib
proc ::init::dependencies { } {
    variable INIT
    
    # Access global array containing options.
    upvar \#0 [lindex $INIT(inits) end] ARGS
    
    log info "Arranging to access $ARGS(-depends)..."
    foreach l $ARGS(-depends) {
		set first 0
		if { [string index $l 0] eq "<" } {
			set l [string trim [string range $l 1 end]]
			set first 1
		}
        ::argutil::accesslib $l "" $first
        if { $ARGS(-splash) ne "" } {
            ::splash::progress $ARGS(splash) "Accessed $l"
        }
    }
}


# ::init::modules -- Initialise modules
#
#       Load modules that this application depends on into the
#       application.  Modules are packages that comply to the coding
#       standards established by the TIL.  Mainly, this implies a
#       logging mechanism that can be controlled and a defaults
#       procedure for setting default options of objects that would be
#       created by the module.
#
# Arguments:
#	-- none -- Takes value from latest inited application
#
# Results:
#       None.
#
# Side Effects:
#       Load modules into memory and set their verbosity level.
proc ::init::modules { } {
    variable INIT
    
    # Access global array containing options.
    upvar \#0 [lindex $INIT(inits) end] ARGS
    upvar \#0 $ARGS(-store) GLBL
    
    log info "Loading modules $ARGS(-load)..."
    foreach m $ARGS(-load) {
        if { [lsearch $ARGS(-quiet) $m] < 0 } {
            log debug "Loading module $m at verbosity $GLBL(verbose)"
            ::argutil::loadmodules $m $GLBL(verbose)
        } else {
            log debug "Loading module $m at default verbosity"
            ::argutil::loadmodules $m
        }
        ::argutil::fix_outlog
        if { $ARGS(-splash) ne "" } {
            ::splash::progress $ARGS(splash) "Loaded $m"
        }
    }
}


proc ::init::slocate { f { progname "" } } {
    variable INIT
    variable libdir
    global argv0
    
    # Access global array containing options, arrange for accessing
    # the default array whenever initialisation hasn't occured yet.
    # This occurs in the (rare) cases when the main program calls this
    # procedure before calling init.
    if { [llength $INIT(inits)] > 0 } {
        upvar \#0 [lindex $INIT(inits) end] ARGS
    } else {
        upvar \#0 [namespace current]::INIT ARGS
        # namespace upvar [namespace current] INIT ARGS; # Not 8.4!
    }
    
    # automagically add the tcl extensions
    set fnames {}
    if { [file extension $f] eq "" } {
        foreach ext $ARGS(-extensions) {
            lappend fnames ${f}.[string trimleft $ext .]
        }
    } else {
        lappend fnames $f
    }
    
    # Now try all possible relative source location directories in
    # order, stop as soon as we've found the file and could source
    # it properly.
    if { $progname eq "" } {
        set progname [file rootname [file tail $argv0]]
    }
    foreach d $INIT(src_locs) {
        set rd [string map [list %progname% $progname] [file join $libdir $d]]
        if { [file isdirectory $rd] } {
            foreach fn $fnames {
                set fname [file join $rd $fn]
                if { [file readable $fname] } {
                    return $fname
                }
            }
        }
    }
    
    return ""
}


# ::init::source -- Source a single file
#
#       Directly source a single file into the application.  These
#       typically are files that are part of the main application but
#       still have not been properly packaged. The procedure will try
#       to find a directory location under the lib directory that is
#       appropriate (a number of them being standardised as part of
#       the src_locs index of the main array, %progname% can be used
#       for resolutions within those directories).
#
# Arguments:
#       f	Raw name of file to look for and source.
#
# Results:
#       Return the full path to the file that was sourced, if success;
#       empty string otherwise.
#
# Side Effects:
#       Load file into memory when found
proc ::init::source { f } {
    variable libdir
    global argv0
    
    set fname [slocate $f]
    if { $fname ne "" } {
        log debug "Loading direct source $fname"
        if { [catch {::source $fname} err] } {
            log error "Could not load source $fname: $err"
        } else {
            return $fname
        }
    }
    
    return ""
}


# ::init::sources -- Initialise direct sources
#
#       Directly source a number of files into the application.  These
#       typically are files that are part of the main application but
#       still have not been properly packaged. The files path are
#       relative to th lib directory of the application.
#
# Arguments:
#	-- none -- Takes value from latest inited application
#
# Results:
#       Return the list of path to the files that were properly sourced.
#
# Side Effects:
#       Load modules into memory and set their verbosity level.
proc ::init::sources { } {
    variable INIT
    
    # Access global array containing options.
    upvar \#0 [lindex $INIT(inits) end] ARGS
    
    log info "Loading direct sources $ARGS(-sources)..."
    set sourced {}
    foreach f $ARGS(-sources) {
        set fname [source $f]   ; # This is source via init module!
        if { $fname eq "" } {
            log warn "Could not find $f for sourcing"
        } else {
            lappend sourced $fname
            if { $ARGS(-splash) ne "" } {
                ::splash::progress $ARGS(splash) \
                        "Loaded [file rootname [file tail $fname]]"
            }
            log debug "Loaded $fname"
        }
    }
    
    return $sourced
}


# ::init::Require -- Require package
#
#       Thin wrapper around package require. This implementation is able to keep
#       the interpreter running when package loading was not a success, if
#       instructed so.
#
# Arguments:
#	pkg	Name of package
#	v	Version to specify, empty for latest available.
#	lazy	Turn this on to accept not being able to load a package.
#
# Results:
#       Version number of package loaded, empty string on errors (package not
#       present)
#
# Side Effects:
#       Return an error and ends program execution when package is not present
#       and lazy was turned off.
proc ::init::Require { pkg {v ""} {lazy 0} } {
    # Construct packge require command, taking the specified version number into
    # account.
    set cmd [list package require $pkg]
    if { $v ne "" } {
        lappend cmd $v
    }
    
    # Accept (or not) when package cannot be loaded.
    if { [string is true $lazy] } {
        if { [catch {eval $cmd} ver] == 0 } {
            return $ver
        } else {
            log warn "Could not load package $pkg: $ver"
        }
    } else {
        set ver [eval $cmd]
        return $ver
    }
    
    return ""
}


# ::init::packages -- Initialise packages
#
#       Initialises regular Tcl/Tk packages that this application
#       might depend on by loading them into memory.  The list of
#       packages is taken from the -packages index that was given to
#       the initialisation routine.  List items are either a package
#       name, or a list formed by a package name and its minimal
#       version number.
#
# Arguments:
#	-- none -- Takes value from latest inited application
#
# Results:
#       Return a list of pairs, each pair being the name of the
#       package and the version number of the instance that was
#       required and sourced.
#
# Side Effects:
#       Requires packages, respecting version number directives if
#       present.
proc ::init::packages { } {
    variable INIT
    
    # Access global array containing options.
    upvar \#0 [lindex $INIT(inits) end] ARGS
    
    log info "Requiring packages $ARGS(-packages)..."
    set reqs {}
    foreach pkg $ARGS(-packages) {
        set lazy 0
        set v ""
        if { [llength $pkg] > 1 } {
            foreach {pkg v} $pkg break
            if { [string index $pkg 0] eq "?" } {
                set pkg [string trim [string range $pkg 1 end]]
                set lazy 1
            }
        } else {
            if { [string index $pkg 0] eq "?" } {
                set pkg [string trim [string range $pkg 1 end]]
                set lazy 1
            }
        }
        set ver [Require $pkg $v $lazy]
        lappend reqs $pkg $ver
        log debug "Loaded package $pkg at version $ver"
        if { $ARGS(-splash) ne "" } {
            ::splash::progress $ARGS(splash) "Required $pkg ($ver)"
        }
    }
    
    return $reqs
}


# ::init::init -- Performs generic program start
#
#       This procedure will perform all the necessary steps during the
#       initialisation of a program.  It will parse the options of the
#       program, ensure that a global variable is initialised with the
#       content of these options (indices are options without the
#       leading dash), will load a number of packages/modules and will
#       ensure that this loading is dynamically shown in a splash
#       window, if relevant.
#
#       The options given to this procedure are as follows:
#       -store     Name of the global variable storing options, defaults
#                  to the name of the program, in upper case.
#       -log       Name of the program for its logger module.
#       -options   list of options that can be given to the cmdline module.
#       -depends   List of pkg & modules that we depend on, localised elsewhere
#       -load      List of packages that should be loaded at proper log level.
#       -quiet     List of packages to keep at their default loglevel (subset
#                  of the -load list).
#       -packages  List of external packages to load in.
#       -sources   List of files to directly source
#       -parsed    Callback to call once options have been parsed and global
#                  variable initialised with their values.
#       -loaded    Callback to call once all necessary modules and packages
#                  have been loaded into memory but before module initialisation
#       -splash    Path to picture for splash, relative to top directory,
#                  empty splash will not load Tk/tile and not show a splash.
#       -outlog    Procedure to receive log messages from all modules.
#       -booleans  List of options that are boolean option (their presence will
#                  set the global variable to 1, otherwise 0).
#       -progress  Number of additional progress states (see -callback)
#       -callback  Command to callback for each additional progress state, this
#                  allows to perform lengthy operations under the cover of the
#                  splash.
#
# Arguments:
#       args	Series of dash-led options and their values, see above.
#
# Results:
#       The name of the global array that is used to store the options.
#
# Side Effects:
#       None.
proc ::init::init { args } {
    variable INIT
    variable libdir
    variable forced_opts
    global auto_path
    global argv0
    global argv
    
    # Automagically bootstrap
    ::source [file join $libdir bootstrap.tcl]
    lappend auto_path $libdir
    ::argutil::accesslib tcllib
    
    # Generate context for this initialisation
    set argstore ::init::args[incr INIT(idgene)]
    upvar \#0 $argstore ARGS
    lappend INIT(inits) $argstore
    
    # Initialised arguments to init with defaults, most of them is
    # just copying, some others need to be dynamic.
    foreach opt [array names INIT -*] {
        switch -- $opt {
            -store {
                set ARGS(-store) [string toupper [__clean_progname]]
		log debug "Using $ARGS(-store) as default global\
                        storage array"
            }
            -log {
                set ARGS(-log) [string tolower [__clean_progname]]
            }
            -options {
                set ARGS(-options) $forced_opts
            }
            -depends {
                set ARGS(-depends) $INIT(-depends)
                if { ! [info exists ::starkit::topdir] } {
                    ::argutil::accesslib lib
                }
            }
            default {
                set ARGS($opt) $INIT($opt)
            }
        }
    }
    
    # Merge initial arguments with the ones that were passed to the
    # init function.
    foreach {opt val} $args {
        switch -glob -- [string tolower $opt] {
            -a* {
                set ARGS(-argsread) $val
            }
            -b* {
                set ARGS(-booleans) $val
            }
            -c* {
                set ARGS(-callback) $val
            }
            -d* {
                foreach m $val {
                    if { [lsearch $ARGS(-depends) $m] < 0 } {
                        lappend ARGS(-depends) $m
                    }
                }
            }
            -loaded {
                set ARGS(-loaded) $val
            }
            -load {
                foreach p $val {
                    lappend ARGS(-load) $p
                }
            }
            -log* {
                set ARGS(-log) $val
            }
            -la* {
                set ARGS(-language) $val
            }
            -op* {
                foreach spec $val {
                    lappend ARGS(-options) $spec
                }
            }
            -ou* {
                set ARGS(-outlog) $val
            }
            -pac* {
                foreach p $val {
                    lappend ARGS(-packages) $p
                }
            }
            -par* {
                set ARGS(-parsed) $val
            }
            -pr* {
                set ARGS(-progress) $val
            }
            -q* {
                foreach p $val {
                    lappend ARGS(-quiet) $p
                }
            }
            -st* {
                set ARGS(-store) $val
            }
            -so* {
                set ARGS(-sources) $val
            }
            -sp* {
                set ARGS(-splash) $val
            }
            -e* {
                set ARGS(-extensions) $val
            }
        }
    }
    
    # Parse the options to the program and put the result into the
    # global array that was guessed or that was passed via -store.
    # Arrange to store a copy of the arguments since argument parsing
    # will destroy these arguments.
    set INIT(argv) $argv
    set INIT(argv0) $argv0
    set INIT(argv_copied) 1
    package require cmdline
    upvar \#0 $ARGS(-store) GLBL
    set inited [::argutil::initargs GLBL $ARGS(-options)]
    if { [catch {::cmdline::typedGetoptions argv $ARGS(-options)} optlist] } {
        puts [::cmdline::typedUsage $ARGS(-options) \
                "accepts the following options:"]
        exit
    }
    
    # Store parsed options into global array
    array set GLBL $optlist
    foreach b $ARGS(-booleans) {
        ::argutil::boolean GLBL [string trimleft $b "-"]
    }
    foreach key $inited {
        ::argutil::makelist GLBL($key)
    }
    
    # Fix package dependency depending on some of the options,
    # i.e. arrange to only require packages when the debug port is
    # set.
    if { [info exists GLBL(dbgport)] && $GLBL(dbgport) > 0 } {
        lappend ARGS(-packages) tkconclient
        lappend ARGS(-depends) tkconclient
        if { $::tcl_platform(platform) eq "windows" } {
            if { [catch {console show} err] } {
                log warn "Cannot open console, running under wish? $err"
            }
        }
    }
    
    # Callback a first time to allow callers to actually modify the
    # arguments to this call.  This is dangerous, so they should
    # really know what they do...
    if { $ARGS(-parsed) ne "" } {
        log debug "Early modification of the arguments"
        if { [catch {eval $ARGS(-parsed) $ARGS(-store) $argstore} err] } {
            log error "Could not execute parsed callback: $err"
        }
    }
    
    # Hurry up showing the splash window, if necessary.
    if { $ARGS(-splash) ne "" } {
        ::argutil::accesslib splash
        package require splash
        set splash_fname [file join [topdir] $ARGS(-splash)]
        if { ! [file exists $splash_fname] } {
            set splash_fname [file join [file dirname [topdir]] $ARGS(-splash)]
        }
        set splash [::splash::new \
                -progress [expr { $ARGS(-progress) \
                    + 4 \
                    + [llength $ARGS(-sources)] \
                    + [llength $ARGS(-depends)] \
                    + [llength $ARGS(-load)] \
                + [llength $ARGS(-packages)]}] \
                -text on \
                -hideall on \
                -imgfile $splash_fname \
                -alpha 0.9]
        set ARGS(splash) $splash
    } else {
        set ARGS(splash) ""
    }
    
    # Initialise local logging facility
    package require logger
    set GLBL(log) [::logger::init $ARGS(-log)]
    $GLBL(log)::setlevel $GLBL(verbose)
    ::argutil::fix_outlog
    
    # Install local language settings.
    set lang [__localisation $GLBL(language)]
    log info "Initial language for application will be: $lang"
    if { $ARGS(-splash) ne "" } {
        ::splash::progress $splash "Language for application $lang"
    }
    
    # Arrange for accessing libraries and loading in packages of various
    # sorts.
    dependencies
    sources
    modules
    packages
    if { $ARGS(-outlog) ne "" } {
        ::argutil::logcb $ARGS(-outlog)
    }
    ::argutil::fix_outlog
    
    # Callback a second time to allow callers to actually modify some
    # of the arguments to the program, or perform some other early
    # initialisation, we read in the arguments ONCE before calling
    # back in order to get some proper defaults anyhow.
    log debug "Initialising to default arguments"
    arguments
    if { $ARGS(-loaded) ne "" } {
        log debug "Give a chance to callers to modify arguments"
        if { [catch {eval $ARGS(-loaded) $ARGS(-store) $argstore} err] } {
            log error "Could not execute parsed callback: $err"
        }
    }
    
    # Read arguments from file if any, adapt verbosity if necessary
    log debug "Now read definitive program arguments list"
    arguments
    if { $ARGS(-splash) ne "" } {
        ::splash::progress $splash "Arguments read and parsed"
    }
    
    # Callback a third time to allow callers to actually know that all
    # arguments to the program have now been parsed from the command
    # line but also read from the files.  All arguments values now are
    # definitive for the remaining of the program's life.
    if { $ARGS(-argsread) ne "" } {
        if { [catch {eval $ARGS(-argsread) $ARGS(-store) $argstore} err] } {
            log error "Could not execute args read callback: $err"
        }
    }
    
    # Listen for debugging sessions
    if { [info exists GLBL(dbgport)] && $GLBL(dbgport) > 0 } {
        if { [catch {::tkconclient::start $GLBL(dbgport)} err] } {
            log warn "Could not start remote debug facility: $err"
        }
    }
    
    # Read configuration files for module-based settings
    configuration GLBL
    if { $ARGS(-splash) ne "" } {
        ::splash::progress $splash "Application configured"
    }
    
    # Install local language settings.
    set lang [__localisation $GLBL(language)]
    log info "Language for application will be: $lang"
    if { $ARGS(-splash) ne "" } {
        ::splash::progress $splash "Language for application $lang"
    }
    
    # Finish up UI initialisation to force in new tile...
    if { $ARGS(-splash) ne "" } {
        package require tile
        package require Tk
    }
    
    # Now deliver init callbacks to force some sort of stepwise
    # initialisation of the program.  This allows to perform "long"
    # operations under the cover of the splash screen.
    for { set i 0 } { $i < $ARGS(-progress) } { incr i } {
        if { $ARGS(-callback) ne "" } {
            if { [catch {eval $ARGS(-callback) $ARGS(-store) $i} err] } {
                log error "Could not execute advance callback: $err"
            }
        }
        if { $ARGS(-splash) ne "" } {
            ::splash::progress $splash "Late initialisation \#$i"
        }
    }
    if { $ARGS(-splash) ne "" } {
        destroy $splash
    }
    
    return $ARGS(-store)
}



# ::init::debughelper -- Install additional debug helpers
#
#       This procedure will turn the program into debugging mode in
#       one-go.  It will automatically turn the verbosity level to
#       debug, it will arrange for the process to listen to incoming
#       tkcon connections on 3456 and will finally dynamically attempt
#       to modify the auto_path to access a number of libraries that
#       are missing when running from a dynamic debugger such as
#       RamDebugger.  This last step only works on windows.
#
# Results:
#       None.
#
# Side Effects:
#       Modifies default options and auto_path for library access,
#       this can have disastrous consequences if you have an older
#       installation of Tcl on your disk
proc ::init::debughelper {} {
    global auto_path
    global tcl_platform
    variable forced_opts
    
    set idx [lsearch -glob -index 0 $forced_opts verbose.*]
    if { $idx >= 0 } {
        set forced_opts [lreplace $forced_opts $idx $idx \
                { verbose.alpha "debug" "Verbosity level" }]
    }
    set idx [lsearch -glob -index 0 $forced_opts dbgport.*]
    if { $idx >= 0 } {
        set forced_opts [lreplace $forced_opts $idx $idx \
                { dbgport.integer "3456" "Port number for debugging sessions" }]
    } else {
        lappend forced_opts { dbgport.integer "3456" "Port number for debugging sessions" }
    }
    
    if { $tcl_platform(platform) eq "windows" } {
        global env
        
        set additional [list [file join $env(ProgramFiles) Tcl]]
        foreach v [file volumes] {
            lappend additional [file join $v Tcl] \
                    [file join [file tail $env(ProgramFiles)] Tcl] \
                    [file join $v Program Tcl] [file join $v Programs Tcl]
        }
        foreach root $additional {
            if { [file isdirectory $root] } {
                # Manually add accessible Tcl/Tk libraries, if any
                foreach v [list 8.6 8.5 8.4 8.3 8.2 8.1 8.0] {
                    set d [file join $root lib tcl$v]
                    if { [file isdirectory $d] } {
                        lappend auto_path $d
                    }
                    set d [file join $root lib tk$v]
                    if { [file isdirectory $d] } {
                        lappend auto_path $d
                    }
                }
                # Manually add teapot controlled libraries
                if { [catch {package require platform} ver] == 0 } {
                    set d [file join $root lib teapot package [::platform::generic] lib]
                    if { [file isdirectory $d] } {
                        lappend auto_path $d
                    }
                }
                foreach t [list tcl tk] {
                    set d [file join $root lib teapot package $t lib]
                    if { [file isdirectory $d] } {
                        lappend auto_path $d
                    }
                }
            }
        }
    }
}


package provide init 1.1