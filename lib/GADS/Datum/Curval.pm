=pod
GADS - Globally Accessible Data Store
Copyright (C) 2014 Ctrl O Ltd

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
=cut

package GADS::Datum::Curval;

use Log::Report;
use Moo;

extends 'GADS::Datum';

has set_value => (
    is       => 'rw',
    trigger  => sub {
        my ($self, $value) = @_;
        my $first_time = 1 unless $self->has_id;
        my $new_id;
        if (ref $value)
        {
            # From database, with enumval table joined
            if ($value = $value->{value})
            {
                $new_id = $value;
                # Look up text value
                my $curval = $self->column->value($value);
                $self->text($curval) if $curval;
            }
        }
        elsif (defined $value) {
            # User input
            $value = undef if !$value; # Can be empty string, generating warnings
            $new_id = $value;
#            my $curval = $self->column->value($value);
#            $self->text($curval->{value}) if $curval;
        }
        unless ($first_time)
        {
            # Previous value
            $self->changed(1) if (!defined($self->id) && defined $value)
                || (!defined($value) && defined $self->id)
                || (defined $self->id && defined $value && $self->id != $value);
            $self->oldvalue($self->clone);
        }
        $self->id($new_id) if defined $new_id || $self->init_no_value;
    },
);

has text => (
    is        => 'rw',
);

has id => (
    is        => 'rw',
    predicate => 1,
    trigger   => sub { $_[0]->blank(defined $_[1] ? 0 : 1) },
);

# Make up for missing predicated value property
sub has_value { $_[0]->has_id }

around 'clone' => sub {
    my $orig = shift;
    my $self = shift;
    $orig->($self, id => $self->id);
};

sub as_string
{   my $self = shift;
    $self->text // "";
}

sub as_integer
{   my $self = shift;
    $self->id // 0;
}

sub html_withlinks
{   my $self = shift;
    my $string = $self->as_string
        or return "";
    my $link = "/record/".$self->id."?oi=".$self->column->refers_to_instance;
    qq(<a href="$link">$string</a>);
}

1;
