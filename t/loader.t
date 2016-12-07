use 5.22.0;

use strictures 2;

use DBI;
use Test2::Bundle::Extended;
use t::common qw(create_dbh table_sql drivers);

use App::SimsLoader::Loader;

sub build_loader {
  my ($driver, $params) = @_;

  if ($driver eq 'sqlite') {
    return App::SimsLoader::Loader->new(
      type => 'SQLite', # Capitalized differently
      dbname => $params->{'--host'},
    );
  }

  if ($driver eq 'mysql') {
    return App::SimsLoader::Loader->new(
      type => $driver,
      dbname => $params->{'--schema'},
      host => $params->{'--host'},
    );
  }

  if ($driver eq 'postgres') {
    return App::SimsLoader::Loader->new(
      type => 'Pg',
      dbname => $params->{'--schema'},
      host => $params->{'--host'},
      username => 'postgres',
      password => 'password',
    );
  }

  die "Don't know how to build loader for $driver";
}

foreach my $driver (drivers()) {
  subtest $driver => sub {
    my ($dbh, $params) = create_dbh({ driver => $driver });

    $dbh->do(table_sql($driver, artists => {
      id => { primary => 1 },
      name => { string => 255, not_null => 1 },
    }));

    my $loader = build_loader($driver, {@$params});

    my %sources = $loader->sources;
    like(
      \%sources,
      { artists => object { call [isa => 'DBIx::Class::ResultSource'] => T() } },
      'The right sources are loaded',
    );

    my $rows = $loader->load({
      artists => [ {name => 'John'}, {name => 'Bob'} ],
    });

    # Validate the $rows here
    # Validate that we have data in the database
    my $artists = $dbh->selectall_arrayref(
      'SELECT * FROM artists', { Slice => {} },
    );

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
