#
# Pretty.pm - Base class for Pretty::* object hierarchy.
#
# $Id: Pretty.pm v0.2, 2008/05/05 14:00 $
#

package Pretty;

#
# Copyright (c) 2008 Shan LeiGuang.
#
# This package is free software and is provided "as is" without express 
# or implied warranty.  It may be used, redistributed and/or modified 
# under the terms of the Perl Artistic License (see
# http://www.perl.com/perl/misc/Artistic.html)
#

use strict;
use vars qw($VERSION);

my $class;

BEGIN {
    $class = __PACKAGE__;
    $VERSION = "0.2";
}

sub VERSION () { "$class v$VERSION" }

1;

__END__

=head1 NAME

C<Pretty> - modules to print something pretty.

=head1 SYNOPSIS

    # Pretty is a base class only

=head1 AUTHOR

Shan LeiGuang E<lt>shanleiguang@gmail.comE<gt>

=cut