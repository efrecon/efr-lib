
				 make

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The make library has a twin goal: providing a pure-Tcl approach to
    expressing  dependencies and  rules  for their  resolution (as  in
    makefiles)  and  automating the  process  of generating  (Windows)
    binaries that are branded with your data.


The make library has grown of some Wiki-posted code for the expression
and resolution of dependencies, as a pure-Tcl replacement for
Makefiles.  It started out of frustration from the complexity of
regular make-based conducts and out of the "emulation" that they offer
on Windows.  Apart from the original code, which has been slightly
modified, the make library provides a number of helper routines for
the production of binaries that are "starpacked".  The library will
allow for the appropriate branding of the resulting binaries so as to
contain icons and data.  In the long run, this libary allows to keep
working as you usually do on a daily basis (IDE, interactive debugger,
etc), while letting you producing versions in a purely automated way
whenever needed.

The library hardly innovates, acting mostly as a centralisation point
for a number of techniques and code-snippets that are available at the
wiki.  Below is an example of a "makefile", as exihibited by this
library (this is pseudo-code, and you will have to adapt to your own
coding habits and locations):

set topdir [file normalize [file dirname [info script]]]

# Source bootstrapping routine.
source ../../../til/bin/argutil.tcl; # You will have to modify

# Now source make-like rule system, you will have to adapt, I place
# all packages under the lib directory, often as "symbolic" (read
# shortcuts) links to their real location
set mkdir [::argutil::resolve_links [file join $topdir lib make]]
source [file join $mkdir lib make.tcl]
source [file join $mkdir lib binmake.tcl]

# Creation of example.exe out of the kit made out of plenty of
# libraries and a main script.
proc some_cleanup { rootdir } {
}

make example.kit from [file join $topdir example.tcl] using {
     ::binmake.kit $::topdir example \
	-tcllib [list log cmdline md5 uri fileutil] \
	-tclbi [list tcom Trf2.1 tcllib_critcl] \
	-tclcore [list msgcat1.3] \
	-lib [list bootstrap.tcl updater] \
	-til [list uobj diskutil permclient errhan massgeturl]
	-copydone some_cleanup
}
make example.exe from example.kit using {
    ::binmake::executable $::topdir example gui \
        appicons [file join pics youricon.ico] \
	version 0.1 descr ${v_app}.exe \
	company "Swedish Institute of Computer Science" \
	copyright "Swedish Institute of Computer Science" \
	product "yourApplication"
}
make example from example.exe using ""

# Cleanup all created "binaries"
make.force clean from [list] using {
    foreach a [list example] {
	puts "Removing $a"
	catch {file delete ${a}.exe}
	catch {file delete ${a}.kit}
    }
}

# Redo all
make all from [list example] using ""

# Glue for default rules and parameters.
proc main {} {
    if {$::argc > 0} {
	foreach a $::argv {
	    eval [lindex $a 0]
	}
    } else {
	eval all
    }
}
main

The make-like rule system is implemented in make.tcl.  binmake.tcl
provides some intelligence to the making of kits (and executables) out
of a hierarchy and an installation.  The package supposes that you
gather all your necessary packages in a sub-directory called lib.
From that sub-directory, symbolic links to other directories are
possible and will be followed.  On Windows, this means shortcuts.  The
package also supposes that you constantly make use of some sort of
central repository for all "official" packages, typically the
ActiveState installation.  It makes a number of good qualified guesses
when you request the construction of a kit out of these packages.

The construction of kits uses a temporary directory to which all
packages and their content is copied and from which the kit is made.
Making the binary will extract the kit back to a temporary directory
and wrap it to its final binary.  This version is geared towards
Windows and it contains kits and binaries at standardised places for
the production of binaries.  When producing binaries, you will get a
chance to associate a Windows icon to the binary as well as tagging it
with product and producer information (the "properties" of a binary
according to the OS).  This is achieved through the construction,
compilation and incorporation of appropriate Windows resources.

make is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:make
