
			       license

Emmanuel Frecon - emmanuel@sics.se
Swedish Institute of Computer Science
Interactive Collaborative Environments Laboratory


			       Abstract

    The license library is  a simplistic license generator and checker
    that seeks  to provide protection  against untrained perpetrators.
    The module  is able to handle  several licenses for  any number of
    products, gathered into a single file.  Licenses can be long-lived
    or temporary and the module  has support for product versions.  It
    is   also   complemented  with   an   example  license   generator
    application.




The license library is not aimed at full-fledged protection.  Cracks,
codes and key generators are legion on the Internet.  Rather, it aims
at providing protection against regular attackers that would attempt
to give away code and binaries to friends.  The library is based on
the idea of signing the user information together with product
information and some secret codes and (controlled) random salt.

Licenses that should be accessed and read are centralised in one file
and ordered in a line-wise fashion.  This allows several products,
people, etc. to share part of the infrastructure.  Licenses are stored
in text files, which allows to send keys (in the form of new license
lines) by mail or via web forms.

The module can also maintain a user database (another text) file,
which allows the organisation to generate unique customer identifiers
as necessary.  This is not mandatory, but every license should be
associated to a customer identifier that has to be an integer.

For the time being, fullscreener has very little documentation and you
will have to read the code.

Generation of licenses and storage of these is made via the
::license::add and ::license::generate commands.  Apart from path to
user database and license file, these take a number of arguments which
are:

-product: The name of the product, this will default to the tail of
	  the script being run (argv0) at all time (which is
	  especially usefull at check time, see below).
-name: Name of the user to which the license is given
-email: Email contact of the user to which the license is given.
-organisation: Organisation or affiliation of the user.
-version: Version number of the product.  The library handles dotted
	  version numbers with two or three parts.  It assumes that
	  minor revisions are given for free, which major versions
	  are considered as different products.
-expiration: Expiration date (clock scan compliant date).  An empty
	     date will lead to a life-time license.
-customer: Identifier of the customer, in which case the user database
	   can be set to an empty string.

The library uses a secret pass phrase.  Their is, on purpose, no other
way to change it than modifying the code of the implementation
itself.  The pass phrase is kept in ::license::LC(secret).

It is up to the caller to check for the validity of the license.  This
is done through calling ::license::check with the path to a license
information file and a number of arguments, which can be:

-product: The name of the product (see above).
-version: The current (run-time!) version of the product.
-exit: If set to true (the default), the library will perform an exit
       if no license matches

If it has not exited, ::license::check will return the list of
matching keys for the product that is currently running.  An empty
list means that no license matched the running product and that this
is an illegal copy.  The caller should then take appropriate measures.

fullscreener is subject to the new BSD license, I would appreciate to
incorporate any modifications and improvements that you make to the
library.

The library is hosted at the following address:
http://www.sics.se/~emmanuel/?Code:license

