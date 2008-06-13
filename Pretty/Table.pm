#
# $Id: Pretty::Table.pm v0.2, 2008-5-7 7:50 $
#

package Pretty::Table;

#
# Copyright (c) 2008 Shan LeiGuang.
#
# This package is free software and is provided "as is" without express 
# or implied warranty.  It may be used, redistributed and/or modified 
# under the terms of the Perl Artistic License (see
# http://www.perl.com/perl/misc/Artistic.html)
#

use strict;
use vars qw($AUTOLOAD);
use Carp;

BEGIN {
    #private vars and methods
    my %_attrs = (
        _data_type       => ['row', 'read/write'],
        _data_format     => ['normal', 'read/write'],
        _data_ref        => [undef, 'read/write'],
        _if_has_title    => [1, 'read/write'],
        _title           => [__PACKAGE__, 'read/write'],
        _indent          => [2, 'read/write'],
        _align           => ['left', 'read/write'],
        _margin_left     => [1, 'read/write'],
        _margin_right    => [1, 'read/write'],
        _deco_horizontal => ['|', 'read/write'],
        _deco_vertical   => ['-', 'read/write'],
        _deco_cross      => ['+', 'read/write'],
        _empty_fill      => [' ', 'read/write'],
        _if_multi_lines  => [1, 'read/write'],
        _max_col_length  => [40, 'read/write'],
        _skip_deco_rows  => [undef, 'read'],
    );
    sub _standard_keys { keys %_attrs; }    
    sub _accessible {
        my ($self, $attr, $mode) = @_;
        $_attrs{$attr}[1] =~ m/$mode/;
    }
    sub _default_for {
        my ($self, $attr) = @_;
        $_attrs{$attr}[0];
    }
    #class methods
    my $_count = 0;
    sub get_count { $_count; }
    sub _incr_count { ++$_count; }
    sub _desr_count { --$_count; }
}

sub new {
    my ($caller, %arg) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = bless {}, $class;
    #init
    foreach my $attr ($self->_standard_keys()) {
        my ($argname) = ($attr =~ m/^_(.*)/);
        if(exists $arg{$argname}) {
            $self->{$attr} = $arg{$argname};
        } elsif($caller_is_obj) {
            $self->{$attr} = $caller->{$attr};
        } else {
            $self->{$attr} = $self->_default_for($attr);
        }
    }
    $self->_incr_count();
    return $self;
}

sub DESTROY { $_[0]->_desc_count(); }

#'set' and 'get' methods
sub AUTOLOAD {
    no strict "refs";
    my ($self, $newval) = @_;
    if($AUTOLOAD =~ m/.*::get(_\w+)/ && $self->_accessible($1, 'read')) {
        my $attr = $1;
        *{$AUTOLOAD} = sub { return $_[0]->{$attr}; };
        return $self->{$attr};
    }
    if($AUTOLOAD =~ m/.*::set(_\w+)/ && $self->_accessible($1, 'read')) {
        my $attr = $1;
        *{$AUTOLOAD} = sub { $_[0]->{$attr} = $_[1]; return; };
        $self->{$1} = $newval;
        return;
    }
    croak "No such method: $AUTOLOAD";
}

sub output {
    my $self           = shift;
    my $data_type      = $self->get_data_type();
    my $data_format    = $self->get_data_format();
    my $data_ref       = $self->get_data_ref();
    my $if_has_title   = $self->get_if_has_title();
    my $title          = $self->get_title();
    my $indent         = $self->get_indent();
    my $align          = $self->get_align();
    my $margin_left    = $self->get_margin_left();
    my $margin_right   = $self->get_margin_right();
    my $deco_h         = $self->get_deco_horizontal();
    my $deco_v         = $self->get_deco_vertical();
    my $deco_c         = $self->get_deco_cross();
    my $empty_fill     = $self->get_empty_fill();
    my $if_multi_lines = $self->get_if_multi_lines();
    my $max_col_length = $self->get_max_col_length();
    my ($max_elem_num, $space) = (0, ' ');
    my (@rows, @cols, @max_lengthes, $total_length, $ptable);
    #strip unnecessary chars
    foreach my $dr (@$data_ref) {
        foreach my $i (0..(@$dr - 1)) {
            $dr->[$i] =~ s/^\s+//;
            $dr->[$i] =~ s/\s+$//;
            $dr->[$i] =~ s/\n//g;
            $dr->[$i] =~ s/s{2,}/ /g;
        }
    }
    #make each arry of @$data_ref the same size
    foreach (@$data_ref) {
        $max_elem_num = @$_ if(@$_ > $max_elem_num);
    }
    foreach my $dref (@$data_ref) {
        if(@$dref < $max_elem_num) {
            for(1..($max_elem_num - @$dref)) {
                push @$dref, $empty_fill;
            }
        }
    }
    #transform @$data_ref to @rows and @cols
    if($data_type eq 'row') {
        @rows = @$data_ref;
        foreach my $row (0..$#{$rows[0]}) {
            push @{$cols[$row]}, $_->[$row] foreach(@rows);
        }
    } elsif($data_type eq 'col') {
        @cols = @$data_ref;
        foreach my $col(0..$#{$cols[0]}) {
            push @{$rows[$col]}, $_->[$col] foreach(@cols);
        }
    }
    #if '_if_multi_lines' enabled, rebuild @rows and @cols
    if($if_multi_lines) {
        my $max_len_rows = [];
        foreach my $i (0..$#rows) {
            my $max_len = 0;
            foreach my $j (0..(@{$rows[$i]} - 1)) {
                if(length($rows[$i]->[$j]) > $max_len) {
                    $max_len = length($rows[$i]->[$j]);
                    $max_len_rows->[$i] = $j;
                }
            }
        }
        my @rows_new;
        $self->{_attrs}->{_skip_deco_rows} = {};
        foreach my $i (0..$#rows) {
            my $max_len_index = $max_len_rows->[$i];
            my $max_array_added = int(length($rows[$i]->[$max_len_index])/$max_col_length);
            foreach my $j (0..$max_array_added) {
                my @array_added;
                foreach my $col (@{$rows[$i]}) {
                    my $sub = substr $col, $j*$max_col_length, $max_col_length;
                    if($sub) {
                        push @array_added, $sub;
                    } else {
                        push @array_added, ' ';
                    }
                }
                if((join '', @array_added) !~ /^\s+$/) {
                    push @rows_new, \@array_added;
                    if(length($rows[$i]->[$max_len_index]) > ($j+1)*$max_col_length) {
                        $self->{_attrs}->{_skip_deco_rows}->{@rows_new-1} = 1;
                    }
                }
            }
        }
        #rebuild @rows and @cols
        @rows = @rows_new;
        undef @cols;
        foreach my $row (0..$#{$rows[0]}) {
            push @{$cols[$row]}, $_->[$row] foreach(@rows);
        }
    }    
    #col's max length = margin_left + max_length + margin_right
    foreach(0..$#cols) {
        my $max_len = length((sort{length($b) <=> length($a)} @{$cols[$_]})[0]);
        $max_lengthes[$_] =  $max_len + $margin_left + $margin_right;
    }
    #print 'title'
    foreach(0..$#{$rows[0]}) {
        $total_length += $max_lengthes[$_];
    }
    $total_length += $#cols;
    if($if_has_title) {
        if($total_length < (length($title) + $margin_left + $margin_right)) {
            $total_length = length($title) + $margin_left + $margin_right;
        }
        #  +----------------------+
        #  | Pretty::Table        |
        #  +----------------------+
        $ptable = ($space x $indent).$deco_c.($deco_v x $total_length).$deco_c."\n";
        $ptable .= ($space x $indent).$deco_h;
        $ptable .= $self->data_format($total_length, $title);
        $ptable .= $deco_h."\n";
    }
    #print 'data'
    #         +----+------+-----+-----+
    $ptable.= $space x $indent;
    foreach(0.. $#{$rows[0]}) {
        $ptable.= $deco_c.($deco_v x $max_lengthes[$_]);
    }
    $ptable.= $deco_c."\n";
    foreach my $i (0..$#rows) {
        #     | id | name | sex | age |
        $ptable.= ($space x $indent).$deco_h;
        foreach(0..$#{$rows[0]}) {
            $ptable.= $self->data_format($max_lengthes[$_], $rows[$i]->[$_]);
            $ptable.= $deco_h;
        }
        $ptable.= "\n";
        if(not $self->{_attrs}->{_skip_deco_rows}->{$i}) {
            # +----+------+-----+-----+
            $ptable.= $space x $indent;
            foreach(0.. $#{$rows[0]}) {
                $ptable.= $deco_c.($deco_v x $max_lengthes[$_]);
            }
            $ptable.= $deco_c."\n";
        }
    }
    return $ptable;
}

sub data_format {
    my ($self, $col_length, $data) = @_;
    my $data_length  = length($data);
    my $align        = $self->get_align();
    my $data_format  = $self->get_data_format();
    my $margin_left  = $self->get_margin_left();
    my $margin_right = $self->get_margin_right();
    my $empty_fill   = $self->get_empty_fill();
    my $data_formated;
    if($data_format eq 'uc') {
        $data = uc($data);
    } elsif($data_format eq 'lc') {
        $data = lc($data);
    } elsif($data_format eq 'ucfirst') {
        $data = ucfirst($data);
    }
    #if 'align' is 'center', recalc $margin_left then set align to 'left'
    if($align eq 'center') {
        $margin_left = int(($col_length - length($data))/2);
        $align = 'left';
    }
    if($align eq 'left') {
        $data_formated .= $empty_fill x $margin_left;
        $data_formated .= $data;
        $data_formated .= $empty_fill x ($col_length - $margin_left - $data_length);
    } elsif($align eq 'right') {
        $data_formated .= $empty_fill x ($col_length - $data_length - $margin_right);
        $data_formated .= $data;
        $data_formated .= $empty_fill x $margin_right;
    }
    return $data_formated;
}

sub insert {
    my ($self, $dref_insert, $index) = @_;
    my $data_ref = $self->get_data_ref();
    if(not $index) {
        push @$data_ref, $dref_insert;
    } else {
        foreach ((@$data_ref - 1)..$index) {
            $data_ref->[$_] = $data_ref->[$_-1];
        }
        $data_ref->[$index] = $dref_insert;
    }
}

#'sort_by' method, only supported on 'row' type
sub sort_by {
    my ($self, $hdrkey, $order) = @_;
    my $data_type = $self->get_data_type();
    my $data_ref  = $self->get_data_ref();
    $order = 'A' if(not $order);
    if($data_type eq 'row') {
        my $hdrref = $data_ref->[0];
        my $hdrkey_index;
        foreach (0..(@$hdrref - 1)) {
            if($hdrref->[$_] =~ m/^$hdrkey$/i) {
                $hdrkey_index = $_;
                last;
            }
        }
        shift(@{$data_ref});
        if($order eq 'A') {
            $data_ref = [ sort{$a->[$hdrkey_index] cmp $b->[$hdrkey_index]} @$data_ref ];
        } elsif($order eq 'D') {
            $data_ref = [ sort{$b->[$hdrkey_index] cmp $a->[$hdrkey_index]} @$data_ref ];
        }
        unshift(@{$data_ref}, $hdrref);
        $self->set_data_ref($data_ref);
    }
}

1;

__END__

=head1 NAME

C<Pretty::Table> - to print pretty text table

=head1 Example

    use Pretty::Table;

    my $pt = Pretty::Table->new(
        data_type      => 'row',     #row mode
        data_format    => 'ucfirst', #uppercase the first char
        if_multi_lines => 1,         #enable multi-lines mode
        max_col_length => 10,        #set max_col_length to 10
    );

    my $dr = [
        ['id','name','sex','age','email'], #this is a row
        ['01','tommy','male',27],
        ['02','jarry','male',26],
        ['03','shanleiguang',26,'shanleiguang@gmail.com'],
    ];

    $pt->set_data_ref($dr);
    $pt->set_title('Contacts');
    $pt->set_align('left');
    $pt->set_data_format('normal');
    $pt->insert(['04','marry','female',26], 4);
    $pt->sort_by('name');
    print $pt->output();

    $pt->set_data_type('col'); #change to 'col' mode
    $pt->set_deco_cross('*');
    $pt->set_if_has_title(0);
    print $pt->output();

=head1 Example Output

  +---------------------------------------------+
  | Contacts                                    |
  +----+------------+--------+-----+------------+
  | id | name       | sex    | age | email      |
  +----+------------+--------+-----+------------+
  | 01 | tommy      | male   | 27  |            |
  +----+------------+--------+-----+------------+
  | 02 | jarry      | male   | 26  |            |
  +----+------------+--------+-----+------------+
  | 03 | shanleigua | male   | 26  | shanleigua |
  |    | ng         |        |     | ng@gmail.c |
  |    |            |        |     | om         |
  +----+------------+--------+-----+------------+
  | 04 | marry      | female | 26  |            |
  +----+------------+--------+-----+------------+

  *-------*-------*-------*------------*--------*
  | id    | 01    | 02    | 03         | 04     |
  *-------*-------*-------*------------*--------*
  | name  | tommy | jarry | shanleigua | marry  |
  |       |       |       | ng         |        |
  *-------*-------*-------*------------*--------*
  | sex   | male  | male  | male       | female |
  *-------*-------*-------*------------*--------*
  | age   | 27    | 26    | 26         | 26     |
  *-------*-------*-------*------------*--------*
  | email |       |       | shanleigua |        |
  |       |       |       | ng@gmail.c |        |
  |       |       |       | om         |        |
  *-------*-------*-------*------------*--------*

=head2 Methods

=over

=item C<Pretty::Table-E<gt>set_data_type(<'row'|'col'>)

    my $dr = [
        ['id','name','sex','age'],  #this is a 'row' or a 'col'
        [...],
    ];

=item C<Pretty::Table-E<gt>set_data_format(<'normal'|'uc'|'lc'|'ucfirst'>)

    normal  - default
    uc      - uppercase
    lc      - lowercase
    ucfirst - uppercase the first char

=item C<Pretty::Table-E<gt>set_data_ref(<$dr>)

    $dr is a 2D ArrayRef:
    my $dr = [
        ['id','name','sex','age'],  #this is a 'row' or a 'col'
        [...],
    ];

=item C<Pretty::Table-E<gt>set_if_has_title(<1|0>)

    default is 1

=item C<Pretty::Table-E<gt>set_title(<$title>)

    default is __PACKAGE__ (Pretty::Table)

=item C<Pretty::Table-E<gt>set_indent(<$indent>)

    default is 2

=item C<Pretty::Table-E<gt>set_align(<'left'|'center'|'right'>)

    default is 'left'

=item C<Pretty::Table-E<gt>set_margin_left(<$margin_left>)

    default is 1, no need to change
    
=item C<Pretty::Table-E<gt>set_margin_right(<$margin_right>)

    default is 1, no need to change

=item C<Pretty::Table-E<gt>set_deco_horizontal(<$deco_h>)

    default is '|', no need to change

=item C<Pretty::Table-E<gt>set_deco_vertical(<$deco_v>)

    default is '-', no need to change

=item C<Pretty::Table-E<gt>set_deco_cross(<$deco_c>)

    default is '+', '*' is also pretty

=item C<Pretty::Table-E<gt>set_empty_fill(<$empty_fill>)

    default is ' '(space), no need to change

=item C<Pretty::Table-E<gt>set_if_multi_lines(<1|0>)

    default is 1, enable multi-lines mode

=item C<Pretty::Table-E<gt>set_max_col_length(<$max_col_length>)

    default is 40, 'if_multi_lines' must enabled

=item C<Pretty::Table-E<gt>insert(<[...]> [,$position])

    $pt->insert(['04','john','male','25']);    #insert to the end of $data_ref
    $pt->insert(['03','john','male','25'], 3); #insert to the '3' position

=item C<Pretty::Table-E<gt>sort_by(<$hdrkey>)

    my $dr = [
        ['id','name','sex','age'],  #be a 'row' or a 'col'
        [...],
    ];
    $pt->set_data_ref($dr);
    $pt->sort_by('id');

=back

=head1 AUTHOR

Shan LeiGuang E<lt>shanleiguang@gmail.comE<gt>

=cut
