#!perl

## Test the "fsm_pages" action

use strict;
use warnings;
use Data::Dumper;
use DBI;
use Test::More tests => 7;
use lib 't','.';
use CP_Testing;

use vars qw/$dbh $SQL $t/;

my $cp = CP_Testing->new( {default_action => 'fsm_pages'} );

$dbh = $cp->test_database_handle();

my $S = q{Action 'fsm_pages'};

$t=qq{$S fails when called with an invalid option};
like ($cp->run('foobar=12'), qr{^\s*Usage:}, $t);

$t=qq{$S fails when called with an invalid option};
like ($cp->run('--warning=40'), qr{ERROR:.+must be a percentage}, $t);

$t=qq{$S fails when called with an invalid option};
like ($cp->run('--critical=50'), qr{ERROR:.+must be a percentage}, $t);

## Create a fake fsm 'view' for testing
$cp->set_fake_schema();
my $schema = $cp->get_fake_schema();
{
	local $dbh->{Warn};
	$dbh->do("DROP TABLE IF EXISTS $schema.pg_freespacemap_pages");
	$dbh->do("DROP TABLE IF EXISTS $schema.pg_freespacemap_relations");
}
$dbh->do(qq{
CREATE TABLE $schema.pg_freespacemap_pages (
  reltablespace oid,
  reldatabase oid,
  relfilenode oid,
  relblocknumber bigint,
  bytes integer
);
});
$dbh->do(qq{
CREATE TABLE $schema.pg_freespacemap_relations (
  reltablespace oid,
  reldatabase oid,
  relfilenode oid,
  avgrequest integer,
  interestingpages integer,
  sortedpages integer,
  nextpage integer
);
});
$dbh->commit();

$t=qq{$S gives normal output for empty tables};
like ($cp->run('--warning=10%'), qr{^POSTGRES_FSM_PAGES OK: .+fsm page slots used: 0 of \d+}, $t);

$dbh->do("INSERT INTO $schema.pg_freespacemap_pages VALUES (1663,16389,16911,34,764)");
$dbh->do("INSERT INTO $schema.pg_freespacemap_relations VALUES (1663,16389,16911,1077,52283,52283,37176)");
$dbh->commit();

$t=qq{$S gives normal warning output};
like ($cp->run('--warning=10%'), qr{^POSTGRES_FSM_PAGES WARNING: .+fsm page slots used: 52288 of \d+}, $t);

$t=qq{$S gives normal critical output};
like ($cp->run('--critical=5%'), qr{^POSTGRES_FSM_PAGES CRITICAL: .+fsm page slots used: 52288 of \d+}, $t);

$t=qq{$S gives normal output for MRTG};
is ($cp->run('--critical=5% --output=MRTG'), qq{34\n52288\n\n\n}, $t);

exit;