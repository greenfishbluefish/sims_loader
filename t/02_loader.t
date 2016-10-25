use strictures 2;

use DBI;
use Test2::Bundle::Extended;
use t::common qw(new_fh);

use App::SimsLoader::Loader;

# Create the tempfile
my ($fh, $fn) = new_fh();

my $dbh = DBI->connect("dbi:SQLite:dbname=$fn", '', '');
$dbh->do("PRAGMA foreign_keys = ON");

$dbh->do("
  CREATE TABLE artists (
    id INTEGER PRIMARY KEY AUTOINCREMENT
   ,name TEXT NOT NULL
  );
");

my $loader = App::SimsLoader::Loader->new(
  type => 'SQLite',
  dbname => $fn,
);

my %sources = $loader->sources;
like(
  \%sources,
  { Artist => object { call [ isa => 'DBIx::Class::ResultSource'] => T() } },
  'The right sources are loaded',
);

my $rows = $loader->load({
  Artist => [ {name => 'John'}, {name => 'Bob'} ],
});

# Validate the $rows here
# Validate that we have data in the database
my $artists = $dbh->selectall_arrayref('SELECT * FROM artists', {Slice => {}});

like(
  $artists, [
    { id => number(1), name => 'John' },
    { id => number(2), name => 'Bob' },
  ],
  'The right rows were loaded',
);

done_testing;