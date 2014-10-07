use utf8;
package GADS::Schema::Result::AlertSend;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

GADS::Schema::Result::AlertSend

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime");

=head1 TABLE: C<alert_send>

=cut

__PACKAGE__->table("alert_send");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 layout_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 alert_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 current_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "layout_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "alert_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "current_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<all>

=over 4

=item * L</layout_id>

=item * L</alert_id>

=item * L</current_id>

=back

=cut

__PACKAGE__->add_unique_constraint("all", ["layout_id", "alert_id", "current_id"]);

=head1 RELATIONS

=head2 alert

Type: belongs_to

Related object: L<GADS::Schema::Result::Alert>

=cut

__PACKAGE__->belongs_to(
  "alert",
  "GADS::Schema::Result::Alert",
  { id => "alert_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 current

Type: belongs_to

Related object: L<GADS::Schema::Result::Current>

=cut

__PACKAGE__->belongs_to(
  "current",
  "GADS::Schema::Result::Current",
  { id => "current_id" },
  { is_deferrable => 1, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 layout

Type: belongs_to

Related object: L<GADS::Schema::Result::Layout>

=cut

__PACKAGE__->belongs_to(
  "layout",
  "GADS::Schema::Result::Layout",
  { id => "layout_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07039 @ 2014-09-22 20:35:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:xGVBRDAj/+rxDmUO1+SESQ


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
