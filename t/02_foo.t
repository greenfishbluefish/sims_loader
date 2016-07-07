use strictures 2;

use Test::More;
use Test::Deep;

use DBI;
use File::Temp qw(tempfile);

use SimsLoader::Loader;

# Create the tempfile
my ($fh, $fn) = tempfile(EXLOCK => 0);

my $dbh = DBI->connect("dbi:SQLite:dbname=$fn", '', '');
$dbh->do("PRAGMA foreign_keys = ON");

$dbh->do("
  CREATE TABLE artists (
    id INTEGER PRIMARY KEY AUTOINCREMENT
   ,name TEXT NOT NULL
  );
");

my $loader = SimsLoader::Loader->new(
  type => 'SQLite',
  dbname => $fn,
);

my $rows = $loader->load({
  Artist => [ {name => 'John'}, {name => 'Bob'} ],
});

# Validate the $rows here
# Validate that we have data in the database
my $artists = $dbh->selectall_arrayref('SELECT * FROM artists', {Slice => {}});

cmp_ok(scalar(@$artists), '==', 2, '2 rows were loaded');
cmp_bag($artists, [
  { id => num(1), name => 'John' },
  { id => num(2), name => 'Bob' },
]);

done_testing;
