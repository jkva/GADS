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

package GADS::Graph;

use GADS::Schema;
use GADS::Util    qw(item_value);
use GADS::View;
use Log::Report;
use Scalar::Util qw(looks_like_number);

use Dancer2 ':script';
use Dancer2::Plugin::DBIC qw(schema resultset rset);

sub all
{   my ($class, $params) = @_;

    my @graphs;
    if (my $user = $params->{user})
    {
        @graphs = rset('Graph')->search({
            'user_graphs.user_id' => $user->{id},
        },{
            join => 'user_graphs',
        })->all;

        if ($params->{all})
        {
            my @g;
            foreach my $g (rset('Graph')->search({},{order_by => 'me.title'})->all)
            {
                my $selected = grep { $_->id == $g->id } @graphs;
                push @g, {
                    id          => $g->id,
                    title       => $g->title,
                    type        => $g->type,
                    description => $g->description,
                    selected    => $selected,
                };
            }
            @graphs = @g;
        }
    }
    else {
        @graphs = rset('Graph')->search({},{order_by => 'me.title'})->all unless @graphs;
    }

    \@graphs;
}

sub delete
{
    my ($self, $graph_id) = @_;

    my $graph = rset('Graph')->find($graph_id)
        or error __x"Unable to find graph {id}", id => $graph_id;
    rset('UserGraph')->search({ graph_id => $graph_id })->delete;
    rset('Graph')->search({ id => $graph_id })->delete;
}

sub dategroup
{
    {
        day   => '%d %B %Y',
        month => '%B %Y',
        year  => '%Y',
    }
}

sub graphtypes
{
    qw(bar line donut scatter pie);
}

sub graph
{   my ($class, $args) = @_;
    my $graph;
    if($args->{submit})
    {
        my $newgraph;
        $newgraph->{title}           = $args->{title} or error __"Please enter a title";
        $newgraph->{description}     = $args->{description};
        $newgraph->{y_axis}          = $args->{y_axis} or error __"Please select a Y-axis";
        $args->{y_axis_stack} eq 'count' || $args->{y_axis_stack} eq 'sum'
            or error __x"{yas} is an invalid value for Y-axis", yas => $args->{y_axis_stack};
        $newgraph->{y_axis_stack}    = $args->{y_axis_stack};
        $newgraph->{y_axis_label}    = $args->{y_axis_label};
        $newgraph->{x_axis}          = $args->{x_axis} or error __"Please select a field for X-axis";
        if ($args->{x_axis_grouping})
        {
            grep { $args->{x_axis_grouping} eq $_ } keys dategroup
                or error __x"{xas} is an invalid value for X-axis grouping", xas => $args->{x_axis_grouping};
        }
        $newgraph->{x_axis_grouping} = $args->{x_axis_grouping};
        $newgraph->{group_by}        = $args->{group_by} ? $args->{group_by} : undef;
        $newgraph->{stackseries}     = $args->{stackseries} ? 1 : 0;
        grep { $args->{type} eq $_ } graphtypes
            or error __x"Invalid graph type {type}", type => $newgraph->{type};
        $newgraph->{type} = $args->{type};
        if ($args->{id})
        {
            my $g = rset('Graph')->find($args->{id})
                or error __x"Requested graph ID {id} not found", id => $args->{id};
            $g->update($newgraph);
        }
        else {
            $args->{id} = rset('Graph')->create($newgraph)->id;
        }

        # Add to all users default graphs if needed
        if ($args->{addgraphusers})
        {
            my @existing = rset('UserGraph')->search({ graph_id => $args->{id} })->all;
            foreach my $user (@{GADS::User->all})
            {
                unless (grep { $_->user_id == $user->id } @existing)
                {
                    rset('UserGraph')->create({
                        graph_id => $args->{id},
                        user_id  => $user->id,
                    });
                }
            }
        }
    }
    
    rset('Graph')->find($args->{id})
        or error __x"Unable to find graph ID {id}", id => $args->{id};
}


# Function to fill out the series of data that will be plotted on a graph
sub data
{
    my ($class, $options) = @_;
    my $graph   = $options->{graph};

    my $y_axis_stack;
    if ($graph->y_axis_stack eq 'count')
    {
        # The count graph groups and counts values. As such, it's
        # only possible to display one field, so take only the first column
        $y_axis_stack = 'count';
    }
    elsif($graph->y_axis_stack eq 'sum') {
        $y_axis_stack = 'sum';
    }
    else {
        error __x"Unknown graph y_axis_stack value {yas}", yas => $graph->y_axis_stack;
    }

    my $series;
    my @xlabels; my @ylabels;

    my $x_axis  = shift GADS::View->columns({ id => $graph->x_axis->id });
    my $y_axis  = shift GADS::View->columns({ id => $graph->y_axis->id });
    my $group_by;
    $group_by = shift GADS::View->columns({ id => $graph->group_by->id })
        if $graph->group_by;

    my $dtgroup;
    my ($datemin, $datemax);
    if ($x_axis->{vtype} eq 'date')
    {
        my $date_fields;
        if ($graph->x_axis_grouping eq 'year')
        {
            $date_fields = {year => 1};
        }
        elsif ($graph->x_axis_grouping eq 'month')
        {
            $date_fields = {year => 1, month => 1};
        }
        elsif ($graph->x_axis_grouping eq 'day')
        {
            $date_fields = {year => 1, month => 1, day => 1};
        }
        else {
            error __x"Unknown grouping for date: {group}", group => $graph->x_axis_grouping;
        }
        $dtgroup = {
            date_fields => $date_fields,
            epoch       => 1,
            interval    => $graph->x_axis_grouping
        };
    }

    # $y_group_index used to count y_group unique values
    my $y_group_index = 0;

    my @colors = ('#FF6961', '#77DD77', '#FFB347', '#AEC6CF', '#FDFD96');

    my @columns = ($x_axis, $y_axis);
    push @columns, $group_by if $group_by;
    my @records = GADS::Record->current({ columns => \@columns, view_id => $options->{view_id}, user => $options->{user}, no_hidden => 0 });

    # Go through each record, and count how many unique values
    # there are for the field in question. Then define the key
    # of the xy_values hash using the index count
    my %xy_values; my %y_group_values;
    foreach my $record (@records)
    {
        my $val  = item_value($x_axis, $record, $dtgroup);
        my $val2 = item_value($group_by, $record, { encode_entities => 0 }) if $group_by;
        if (!defined $xy_values{$val})
        {
            $xy_values{$val} = 1;
            push @xlabels, $val;
        }
        if ($group_by && !defined $y_group_values{$val2})
        {
            $y_group_values{$val2} = { color => $colors[$y_group_index], defined => 0 };
            $y_group_index++;
        }
        if ($x_axis->{vtype} eq 'date')
        {
            next unless $val;
            $datemin = $val if !defined $datemin || $datemin > $val;
            $datemax = $val if !defined $datemax || $datemax < $val;
        }
    }

    @xlabels = sort @xlabels;
    my $count = 0;
    if ($dtgroup && $datemin && $datemax)
    {
        @xlabels = ();
        my $inc = DateTime->from_epoch( epoch => $datemin );
        my $add = $dtgroup->{interval}.'s';
        while ($inc->epoch <= $datemax)
        {
            $xy_values{$inc->epoch} = $count;
            my $dg = dategroup;
            my $df = $dg->{$dtgroup->{interval}};
            push @xlabels, $inc->strftime($df);
            $inc->add( $add => 1 );
            $count++;
        }
    }
    else
    {
        foreach my $l (@xlabels)
        {
            $xy_values{$l} = $count;
            $count++;
        }
    }
    
    # $fieldcol is the field that is used for each column on the graph
    # (i.e. what is being grouped by)
    my $fieldcol = "field".$y_axis->{id};

    # Now go into each record a second time, counting the values for each
    # of the above unique values, and setting the count into the series hash
    foreach my $record (@records)
    {
        $dtgroup->{encode_entities} = 0; # Filled with DT options for date, otherwise just need this option
        $dtgroup->{plain} = 1; # No fancy formatting for values
        my $x_value = item_value($x_axis, $record, $dtgroup); # The actual value of the field
        my $y_value = item_value($y_axis, $record, { encode_entities => 0, plain => 1 }); # The actual value of the field
        my $groupby_val;
        $groupby_val = item_value($group_by, $record, { encode_entities => 0, plain => 1 }) if $group_by;

        my $key;
        if ($graph->type eq "pie")
        {
            $key = 1; # Only ever one key for the one ring of a pie
        }
        elsif ($graph->type eq "donut")
        {
            $key = $groupby_val || 1; # Maybe no grouping will be set
        }
        elsif ($y_axis_stack eq 'sum' && !$groupby_val)
        {
            $key = 1; # Only one series
        }
        else {
            $key = $y_axis_stack eq 'count' ? $y_value : $groupby_val;
        }
        next unless $key;
        unless ($graph->type eq "pie" || $graph->type eq "donut" || defined $series->{$key})
        {
            # If not defined, zero out the field's values
            my @zero = (0) x $count;
            $series->{$key}->{data} = \@zero;
            $series->{$key}->{y_group} = $groupby_val;
        }
        # Finally increase by one the particlar value count in question
        my $idx = $xy_values{$x_value};
        if ($y_axis_stack eq 'count')
        {
            $series->{$key}->{data}->[$idx]++;
        }
        elsif(looks_like_number $y_value) {
            $series->{$key}->{data}->[$idx] += $y_value if $y_value;
        }
        else {
            $series->{$key}->{data}->[$idx] = 0 unless $series->{$key}->{data}->[$idx];
        }
    }

    my $markeroptions = $graph->type eq "scatter"
                      ? '{ size: 7, style:"x" }'
                      : '{ show: false }';

    my @all_series;
    if ($graph->type eq "pie" || $graph->type eq "donut")
    {
        foreach my $k (keys %$series)
        {
            my @points;
            my $s = $series->{$k}->{data};
            foreach my $item (keys %xy_values)
            {
                my $idx = $xy_values{$item};
                $item =~ s!'!\\\'!g;
                push @points, [
                    "'$item'", $s->[$idx],
                ] if $s->[$idx]
            }
            push @all_series, \@points;
        }
    }
    else {
        # Now work out the Y labels for each point. Go into each data set and
        # see if there is a value. If there is, set the label, otherwise leave
        # it blank in order to show no label at that point
        foreach my $k (keys %$series)
        {
            my @row;
            my $s = $series->{$k}->{data};
            foreach my $point (@$s)
            {
                my $label = $point ? $k : '';
                push @row, $label;
            }
            my $y_group = $series->{$k}->{y_group} || '';
            my $showlabel;
            if (!$y_group || $y_group_values{$y_group}->{defined})
            {
                $showlabel = 'false';
            }
            else {
                $showlabel = 'true';
                $y_group_values{$y_group}->{defined} = 1;
            }
            $series->{$k}->{label} = {
                points        => \@row,
                color         => $y_group_values{$y_group}->{color},
                showlabel     => $showlabel,
                showline      => $graph->type eq "scatter" ? 'false' : 'true',
                markeroptions => $markeroptions,
                label         => $y_group
            };
        }

        # Sort the series by y_group, so that the groupings appear together on the chart
        @all_series = values $series;
        @all_series = sort { $a->{y_group} cmp $b->{y_group} } @all_series if $group_by;
    }

    # Legend is shown for secondary groupings. No point otherwise.
    my $showlegend = $graph->group_by || $graph->type eq "pie" || $graph->type eq "donut" ? 'true' : 'false';
    # Other graph options from graph definition
    my $stackseries = $graph->stackseries && $graph->type ne "donut" && $graph->type ne "pie" ? 'true' : 'false';
    my $type = $graph->type ? $graph->type : 'line';

    # Escape any quotes for the JS in the template. XXX Should probably
    # move this code to the template itself
    @xlabels = map {$_ =~ s!'!\\\'!g; $_} @xlabels;
    @ylabels = map {$_ =~ s!'!\\\'!g; $_} @ylabels;

    # The graph hash
    {
        dbrow       => $graph,
        xlabels     => \@xlabels,
        ylabels     => \@ylabels,
        series      => \@all_series,
        showlegend  => $showlegend,
        stackseries => $stackseries,
        type        => $type,
    };
}





1;


