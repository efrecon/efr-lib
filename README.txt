This directory contains a number of libraries that are of general
interest and that can be reused in other projects if necessary.  I
have made available a number of these libraries under the BSD
license.

There should be one library per directory.  The root directory of the
library should only contain a README file and a license file.  It can
contain any number of sub-directories, but at least the implementation
of the library.

These libraries are all placed under the control of bzr for version
control.

To generate a release, do the following command from this directory.
Then, you should modify the name of the generated tar file to reflect
the version number of the library and move it to the revs directory.

tclsh ../../til/utils/make_distro.tcl -dexclude "(CVS|.bzr)" -dirs <libname>

Libraries that internally rely on binaried or other DLLs should be
created using the following command:

tclsh ../../til/utils/make_distro.tcl -dexclude "(CVS|.bzr)" -fexclude "(~|.bak|.chm|.tpj)$" -dirs <libname>
