use Test::More; # tests => 1;
use strict;
use warnings;

use Log::Report;

use t::lib::DataSheet;

my $sheet_site1 = t::lib::DataSheet->new(site_id => 1);
my $schema      = $sheet_site1->schema;
$sheet_site1->create_records;
$schema->site_id(2);
my $sheet_site2 = t::lib::DataSheet->new(schema => $schema, instance_id => 2);
$sheet_site2->create_records;

# Check site 1 records
$schema->site_id(1);
my $records_site1 = GADS::Records->new(
    user    => undef,
    layout  => $sheet_site1->layout,
    schema  => $schema,
);
is( $records_site1->count, 2, "Correct number of records in site 1" );
my @current_ids = map { $_->current_id } @{$records_site1->results};
is( "@current_ids", "1 2", "Current IDs correct for site 1" );
# Try and access record from site 2
my $record = GADS::Record->new(
    user   => undef,
    layout => $sheet_site1->layout,
    schema => $schema,
);
is( $record->find_current_id(1)->current_id, 1, "Retrieved record from same site (1)" );
$record->clear;
try {$record->find_current_id(3)};
ok( $@, "Failed to retrieve record from other site (2)" );

# Site 2 tests
$schema->site_id(2);
my $records_site2 = GADS::Records->new(
    user    => undef,
    layout  => $sheet_site2->layout,
    schema  => $schema,
);

is( $records_site2->count, 2, "Correct number of records in site 2" );
@current_ids = map { $_->current_id } @{$records_site2->results};
is( "@current_ids", "3 4", "Current IDs correct for site 2" );

# Try and access record from site 1
$record = GADS::Record->new(
    user   => undef,
    layout => $sheet_site2->layout,
    schema => $schema,
);
is( $record->find_current_id(3)->current_id, 3, "Retrieved record from same site (2)" );
$record->clear;
try {$record->find_current_id(1)};
ok( $@, "Failed to retrieve record from other site (1)" );
done_testing();
