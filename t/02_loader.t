use 5.20.0;
use strictures 2;

use Test::More;
use Test::Deep;

use DBI;

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
cmp_deeply(
  \%sources,
  { Artist => isa('DBIx::Class::ResultSource') },
  'The right sources are loaded',
);

my $rows = $loader->load({
  Artist => [ {name => 'John'}, {name => 'Bob'} ],
});

# Validate the $rows here
# Validate that we have data in the database
my $artists = $dbh->selectall_arrayref('SELECT * FROM artists', {Slice => {}});

cmp_bag(
  $artists, [
    { id => num(1), name => 'John' },
    { id => num(2), name => 'Bob' },
  ],
  'The right rows were loaded',
);

done_testing;
