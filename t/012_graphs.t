use Test::More; # tests => 1;
use strict;
use warnings;

use Log::Report;
use GADS::Graph;
use GADS::Graph::Data;
use GADS::Records;
use GADS::RecordsGroup;

use t::lib::DataSheet;

my $data = [
    {
        string1    => 'Foo',
        date1      => '2013-10-10',
        daterange1 => ['2014-03-21', '2015-03-01'],
        integer1   => 10,
        enum1      => 1,
    },{
        string1    => 'Bar',
        date1      => '2014-10-10',
        daterange1 => ['2010-01-04', '2011-06-03'],
        integer1   => 15,
        enum1      => 1,
    },{
        string1    => 'Bar',
        integer1   => 35,
        enum1      => 2,
    },{
        string1    => 'FooBar',
        date1      => '2016-10-10',
        daterange1 => ['2009-01-04', '2017-06-03'],
        integer1   => 20,
        enum1      => 2,
    },
];

my $sheet = t::lib::DataSheet->new(data => $data);

my $schema = $sheet->schema;
my $layout = $sheet->layout;
my $columns = $sheet->columns;
$sheet->create_records;

my $graphs = [
    {
        name         => 'String x-axis, integer sum y-axis',
        type         => 'bar',
        x_axis       => $columns->{string1}->id,
        y_axis       => $columns->{integer1}->id,
        y_axis_stack => 'sum',
        data         => [[ 50, 10, 20 ]],
    },
    {
        name            => 'Date range x-axis, integer sum y-axis',
        type            => 'bar',
        x_axis          => $columns->{daterange1}->id,
        x_axis_grouping => 'year',
        y_axis          => $columns->{integer1}->id,
        y_axis_stack    => 'sum',
        data            => [[ 20, 35, 35, 20, 20, 30, 30, 20, 20 ]],
    },
    {
        name            => 'Date x-axis, integer count y-axis',
        type            => 'bar',
        x_axis          => $columns->{date1}->id,
        x_axis_grouping => 'year',
        y_axis          => $columns->{string1}->id,
        y_axis_stack    => 'count',
        data            => [[ 1, 1, 0, 1 ]],
    },
    {
        name         => 'String x-axis, sum y-axis, group by enum',
        type         => 'bar',
        x_axis       => $columns->{string1}->id,
        y_axis       => $columns->{integer1}->id,
        y_axis_stack => 'sum',
        group_by     => $columns->{enum1}->id,
        data         => [[ 35, 0, 20 ], [ 15, 10, 0 ]],
,
    },
];

foreach my $g (@$graphs)
{
    my $graph = GADS::Graph->new(
        layout => $layout,
        schema => $schema,
    );
    $graph->title($g->{name});
    $graph->type($g->{type});
    $graph->x_axis($g->{x_axis});
    $graph->x_axis_grouping($g->{x_axis_grouping})
        if $g->{x_axis_grouping};
    $graph->y_axis($g->{y_axis});
    $graph->y_axis_stack($g->{y_axis_stack});
    $graph->group_by($g->{group_by})
        if $g->{group_by};
    $graph->write;

    my $records = GADS::RecordsGroup->new(
        user              => undef,
        layout            => $layout,
        schema            => $schema,
    );
    my $graph_data = GADS::Graph::Data->new(
        id      => $graph->id,
        records => $records,
        schema  => $schema,
    );

    is_deeply($graph_data->points, $g->{data}, "Graph data for $g->{name} is correct");
}

done_testing();