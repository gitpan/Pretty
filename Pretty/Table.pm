#
# $Id: Pretty::Table.pm v0.3, 2009-01-31 09:50 $
#
# This is free software.
#
# Changes log:
#   (1)2008-05-07 v0.2
#   (2)2009-01-31 v0.3
#       fix some bugs;
#       remove 'insert' method, replaced by 'add' method;
#
# Thanks:
#   mbailey@cpan.org
#   maciej.pijanka@gmail.com
#

package Pretty::Table;

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
        _empty_fill      => [' ', 'read'],
        _if_multi_lines  => [1, 'read/write'],
        _max_col_length  => [40, 'read/write'],
        _skip_deco_rows  => [undef, 'read/write'],
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
    sub _decr_count { --$_count; }
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

sub DESTROY { $_[0]->_decr_count(); }

#'set' and 'get' methods
sub AUTOLOAD {
    no strict "refs";
    my ($self, $newval) = @_;
    if($AUTOLOAD =~ m/.*::get(_\w+)/ && $self->_accessible($1, 'read')) {
        my $attr = $1;
        *{$AUTOLOAD} = sub { return $_[0]->{$attr}; };
        return $self->{$attr};
    }
    if($AUTOLOAD =~ m/.*::set(_\w+)/ && $self->_accessible($1, 'write')) {
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
            $dr->[$i] =~ s/\s{2,}/ /g;
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
                    if(defined $sub) {
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
        #     +-----------------------+
        #     | Pretty::Table         |
        #     +-----------------------+
        $ptable  = ($space x $indent).$deco_c.($deco_v x $total_length).$deco_c."\n";
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

sub add {
    my ($self, $dref_add) = @_;
    my $data_ref = $self->get_data_ref();
    push @$data_ref, $dref_add;
}

#'sort_by' table header field, the first row/col is table header
sub sort_by {
    my ($self, $hdrkey, $order) = @_;
    my $data_type = $self->get_data_type();
    my $data_ref  = $self->get_data_ref();
    $order = 'A' if(not $order);
    my $hdrref = $data_ref->[0]; #the first row/col is table header
    my $hdrkey_index;
    foreach (0..(@$hdrref - 1)) {
        if($hdrref->[$_] =~ m/^$hdrkey$/i) {
            $hdrkey_index = $_;
            last;
        }
    }
    return if(not defined $hdrkey_index); #return if not found '$hdrkey' in headers
    shift(@{$data_ref}); #not sort the header
    if($order eq 'A') {
        $data_ref = [ sort{$a->[$hdrkey_index] cmp $b->[$hdrkey_index]} @$data_ref ];
    } elsif($order eq 'D') {
        $data_ref = [ sort{$b->[$hdrkey_index] cmp $a->[$hdrkey_index]} @$data_ref ];
    }
    unshift(@{$data_ref}, $hdrref);
    $self->set_data_ref($data_ref);
}

1;

__END__

=head1 NAME

C<Pretty::Table> - to print pretty text table

=head1 Example

    use Pretty::Table;

    my $pt = Pretty::Table->new(
        data_type      => 'row',     #row mode
        data_format    => 'ucfirst', #upper char
        if_multi_lines => 1,         #enable multi-lines mode
        max_col_length => 15,        #set max_col_length to 15
    );

    my $dr = [
        ['id','name','sex','age','email'],
        ['01','tommy','male',27],
        ['02','jarry','male',26],
        ['03','shanleiguang','male',28,'shanleiguang@gmail.com'],
    ];

    $pt->set_data_ref($dr);
    $pt->set_align('left');
    $pt->set_data_format('normal');
    $pt->add(['05','jackie','male',27,'jakie@somedoain.com']);
    $pt->add(['04','marry','female',26]);
    $pt->sort_by('id');
    $pt->set_title("Contacts(sorted by 'id')");
    print $pt->output();
    $pt->sort_by('name');
    $pt->set_title("Contacts(sorted by 'name')");
    print $pt->output();

    $pt->set_data_type('col');
    $pt->set_deco_cross('*');
    $pt->set_if_has_title(0);
    $pt->sort_by('id');
    print $pt->output();

=head1 Example Output

  +----------------------------------------------------+
  | Contacts(sorted by 'id')                           |
  +----+--------------+--------+-----+-----------------+
  | id | name         | sex    | age | email           |
  +----+--------------+--------+-----+-----------------+
  | 01 | tommy        | male   | 27  |                 |
  +----+--------------+--------+-----+-----------------+
  | 02 | jarry        | male   | 26  |                 |
  +----+--------------+--------+-----+-----------------+
  | 03 | shanleiguang | male   | 0   | shanleiguang@gm |
  |    |              |        |     | ail.com         |
  +----+--------------+--------+-----+-----------------+
  | 04 | marry        | female | 26  |                 |
  +----+--------------+--------+-----+-----------------+
  | 05 | jackie       | male   | 27  | jakie@somedoain |
  |    |              |        |     | .com            |
  +----+--------------+--------+-----+-----------------+
  +----------------------------------------------------+
  | Contacts(sorted by 'name')                         |
  +----+--------------+--------+-----+-----------------+
  | id | name         | sex    | age | email           |
  +----+--------------+--------+-----+-----------------+
  | 05 | jackie       | male   | 27  | jakie@somedoain |
  |    |              |        |     | .com            |
  +----+--------------+--------+-----+-----------------+
  | 02 | jarry        | male   | 26  |                 |
  +----+--------------+--------+-----+-----------------+
  | 04 | marry        | female | 26  |                 |
  +----+--------------+--------+-----+-----------------+
  | 03 | shanleiguang | male   | 0   | shanleiguang@gm |
  |    |              |        |     | ail.com         |
  +----+--------------+--------+-----+-----------------+
  | 01 | tommy        | male   | 27  |                 |
  +----+--------------+--------+-----+-----------------+
  *-------*-------*-------*-----------------*--------*-----------------*
  | id    | 01    | 02    | 03              | 04     | 05              |
  *-------*-------*-------*-----------------*--------*-----------------*
  | name  | tommy | jarry | shanleiguang    | marry  | jackie          |
  *-------*-------*-------*-----------------*--------*-----------------*
  | sex   | male  | male  | male            | female | male            |
  *-------*-------*-------*-----------------*--------*-----------------*
  | age   | 27    | 26    | 0               | 26     | 27              |
  *-------*-------*-------*-----------------*--------*-----------------*
  | email |       |       | shanleiguang@gm |        | jakie@somedoain |
  |       |       |       | ail.com         |        | .com            |
  *-------*-------*-------*-----------------*--------*-----------------*

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

=item C<Pretty::Table-E<gt>add(<[...]>)

    $pt->add(['04','john','male','25']); #add to the end of $data_ref

=item C<Pretty::Table-E<gt>sort_by(<$hdrkey>,['A|D'])

    my $dr = [
        ['id','name','sex','age'],
        [...],
    ];
    $pt->set_data_ref($dr);
    $pt->sort_by('id');

=back

=head1 AUTHOR

Shan LeiGuang E<lt>shanleiguang@gmail.comE<gt>

=cut
