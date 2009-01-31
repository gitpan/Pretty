#
# $Id: Pretty.pm v0.3, 2009/01/31 21:00 $
#
# This is free software.
#

package Pretty;

use strict;
use vars qw($VERSION);

my $class;

BEGIN {
    $class = __PACKAGE__;
    $VERSION = "0.3";
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