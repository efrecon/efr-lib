
			       updater

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The updater is a library that aims at facilitating the auto-update
    of  software  over  the  Internet.   It will  poll  on  demand  or
    regularily a  location and will download any  newer version posted
    to that  location to  a local file.   Newer versions  are detected
    through MD5  digests, which values  are posted along  the Internet
    location.


The updater is a library that aims at facilitating the auto-update of
software over the Internet.  It will poll on demand or regularily a
location and will download any newer version posted to that location
to a local file.  Detection of newer versions is done via MD5
digests.  To that end, the library enforces a distribution method
which consists of posting MD5 index files along with a (set of) files,
typically in a common directory.

For the time being, the updater library has very little documentation
and you will have to read the code.  Basically, the idea is to give
contracts to the library, which will take a number of decisions as
instructed by these contracts.  There should be one contract per file
to be updated, and one contract per updater object created via the
libary.  When a new version of a file is to be released, it will be
placed within an Internet accessible directory and the MD5SUMS file,
in that directory, will be updated to reflect the digest of the new
file.  At the next check, the updater library will detect the
difference in digest and automatically download and install the new
file, typically a new software.  Contracts are establishing the
locations of all these Internet resources and local files, which are
completely parametrisabled.

Installing software, typically already running such, is not an easy
task.  This is especially true on Windows, an operating system on
which the executables of an application are locked for all access when
the application is running.  To this end, the library provides some
support to killing the application before its new version is
installed.  However, there is currently no way to restart the
application.

New contracts are created with the command ::updater::new, the command
takes a file describing the contract and/or a number of key values
parameters (options).  The options will always prevail over the file.
The options recognised by the updater "object" are the following, when
found in a contract file, they do not need to be led by a dash:

-source is a URL that points to the location where newer versions of
the file should be placed.

-sums is a (relative or absolute) URL that points to the location of
a file that contains MD5 sums for (among others) the source.  When
the URL is relative, it will be resolved to the URL of the source,
which allows to keep the source and the sums in the same directory
on a server.  The file can contain any number of lines (commented
and empty lines being ignored) and is understood as follows: the
first item in lines is the MD5 sum, the second a file name.  This
file name will be matched against the one pointed at by the source.
This (somewhat) complicated scheme allows to keep a number of
sources and index these by a single MD5 sum description file if
necessary.

-target is the full path to where the remote file should be placed
when the remote differs from the installed version.  The target
recognises idioms such as %progdir% and %user%, the complete list
being available from the ::diskutil::fname_resolv documentation.
This allows for maximal flexibility.

-destroy describes is the method that should be used for "removing"
the component.  There are two methods that are currently supported:
writing an (exit) command on a socket, or killing a process.  These
are identified by the keywords SOCKET and KILL respectively.  Both
methods can take additional arguments, which are simply whitespace
separated arguments following the keyword.  SOCKET takes the port
number to which the update module should connect (this will always
be on the localhost); the remaining of the arguments forming the
command to send on that socket (defaulting to EXIT).  KILL takes as
arguments any number of strings that should be looked for when
looking for the process to kill.  These default to the name of the
target.  The first process identifiers matching these strings will
be killed prior to installation.

-period is the number of seconds to regularily check for new
versions.  An empty string will lead to checking once only, i.e. at
creation.

-install_attempts is the number of times the updater tries to
install the remote source onto the old version of the target.  The
module tries several times in case resources are not completely
freed immediately after the destruction procedure described above.

-install_wait is the number of milliseconds to wait before
installation attempts.

The command returns an identifier for the updater.  This identifier
identifies the updating contract uniquely and you can perform a number of
operations on it:

* config will reconfigure the creation options or return these options.

* check will check for one or periodical updates.

updater is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:updater
