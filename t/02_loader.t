use strictures 2;

use DBI;
use Test2::Bundle::Extended;
use t::common qw(create_dbh table_sql);

use App::SimsLoader::Loader;

# These are capitalized specifically to match the DBD::<> names.
foreach my $driver (qw(SQLite mysql)) {
  subtest $driver => sub {
    my ($dbh, $params) = create_dbh({ driver => lc($driver) });
    my %params = @$params;

    $dbh->do(table_sql(lc($driver), artists => {
      id => { primary => 1 },
      name => { string => 255, not_null => 1 },
    }));
    my $loader;
    if (lc($driver) eq 'sqlite') {
      $loader = App::SimsLoader::Loader->new(
        type => $driver,
        dbname => $params{'--host'},
      );
    }
    elsif (lc($driver) eq 'mysql') {
      $loader = App::SimsLoader::Loader->new(
        type => $driver,
        dbname => $params{'--schema'},
        host => $params{'--host'},
      );
    }

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
  };
}

done_testing;
