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
      type => 'SQLite',
      dbname => $params->{'--host'},
    );
  }

  if ($driver eq 'mysql') {
    return App::SimsLoader::Loader->new(
      type => $driver,
      database => $params->{'--schema'},
      host     => $params->{'--host'},
      username => $params->{'--username'},
      password => $params->{'--password'},
    );
  }

  if ($driver eq 'postgres') {
    return App::SimsLoader::Loader->new(
      type => 'Pg',
      database => $params->{'--schema'},
      host     => $params->{'--host'},
      username => $params->{'--username'},
      password => $params->{'--password'},
    );
  }

  if ($driver eq 'oracle') {
    return App::SimsLoader::Loader->new(
      type => 'Oracle',
      sid  => $params->{'--sid'},
      host => $params->{'--host'},
      username => $params->{'--username'},
      password => $params->{'--password'},
    );
  }

  if ($driver eq 'sqlserver2016') {
    return App::SimsLoader::Loader->new(
      type => 'ODBC',
      sid  => $params->{'--sid'},
      host => $params->{'--host'},
      username => $params->{'--username'},
      password => $params->{'--password'},
    );
  }

  die "Don't know how to build loader for $driver";
}

foreach my $driver (drivers()) {
  subtest $driver => sub {
    my ($dbh, $params) = create_dbh({ driver => $driver });

    table_sql($driver, $dbh, artists => {
      id => { primary => 1 },
      name => { string => 255, not_null => 1 },
    });

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

    # Necessary for Oracle to return lowercase column names.
    $dbh->{FetchHashKeyName} = 'NAME_lc';
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
