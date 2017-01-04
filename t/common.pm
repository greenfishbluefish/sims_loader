package # Hide from PAUSE
  t::common;

use strictures 2;

use 5.22.0;

use base 'Exporter';
our @EXPORT_OK = qw(
  drivers
  new_fh
  create_dbh
  table_sql
  run_test
  success
);

# Load this here to avoid warnings re: Test2
use Test::Builder;

use App::Cmd::Tester;
use DBI;
use File::Spec ();
use File::Temp qw( tempfile tempdir );
use Fcntl qw( :flock );
use Test2::Bundle::Extended;
use Test2::Tools::AsyncSubtest;
use YAML::Any qw(Dump Load);

my $parent = $ENV{WORK_DIR} || File::Spec->tmpdir;
our $dir = tempdir( CLEANUP => 1, DIR => $parent );

sub drivers {
  return qw(sqlite mysql postgres oracle);
}

sub new_fh {
  my ($fh, $filename) = tempfile('tmpXXXX',
    DIR => $dir,
    EXLOCK => 0,
    UNLINK => 1,
  );

  # This is because tempfile() returns a flock'ed $fh on MacOSX.
  flock $fh, LOCK_UN;

  return ($fh, $filename);
}

sub create_dbh_nonsqlite {
  my ($driver, %db) = @_;

  my $conn = "host=$db{host};port=$db{port}";
  $conn .= ";sid=$db{sid}" if exists $db{sid};

  my $dbh = DBI->connect(
    "dbi:$db{driver}:$conn", $db{user}, $db{pass}, {
      PrintError => 0, RaiseError => 1,
    },
  ) or die "Cannot connect to $driver database: $DBI::errstr\n";

  my @addl = (
    '--host', $db{host},
    '--port', $db{port},
  );

  # For Oracle, the username and password initially supplied will be for a
  # service-level administrator. Create a real user (and thus a schema).
  if ($driver eq 'oracle') {
    # NOTE: Oracle doesn't want the semi-colons.

    # This will fail the first time it's run; Oracle doesn't have 'IF EXISTS'.
    eval { $dbh->do("DROP USER $db{name} CASCADE"); };

    # Use the schema as the username/password.
    $dbh->do("CREATE USER $db{name} IDENTIFIED by $db{name}");
    $dbh->do("GRANT CONNECT, RESOURCE TO $db{name}");
    $db{user} = $db{pass} = $db{name};

    push @addl, ( '--sid', $db{sid} ),
  }
  else {
    $dbh->do("DROP DATABASE IF EXISTS $db{name};");
    $dbh->do("CREATE DATABASE $db{name};");

    # Non-Oracle databases now want to use the newly-created DB name.
    $conn .= ";database=$db{name}";

    push @addl, ( '--schema', $db{name} ),
  }
  $dbh->disconnect;

  $dbh = DBI->connect(
    "dbi:$db{driver}:$conn", $db{user}, $db{pass}, {
      PrintError => 0, RaiseError => 1,
    },
  ) or die "Cannot connect to $driver database: $DBI::errstr\n";

  push @addl, (
    '--username', $db{user},
    '--password', $db{pass},
  );

  return ($dbh, \@addl);
}

sub create_dbh {
  my ($options) = @_;
  my $driver = $options->{driver}
    // die "Must specify --driver for create_dbh()";

  if ($driver eq 'sqlite') {
    my ($fh, $fn) = new_fh();
    my $dbh = DBI->connect("dbi:SQLite:dbname=$fn", '', '')
      or die "Cannot connect to $driver database: $DBI::errstr\n";
    my @addl = (
      '--host', $fn,
    );

    return ($dbh, \@addl);
  }
  elsif ($driver eq 'mysql') {
    return create_dbh_nonsqlite(
      $driver,
      name => 'foo',
      host => 'mysql',
      port => '3306',
      user => 'root',
      pass => '',
      driver => 'mysql',
    );
  }
  elsif ($driver eq 'postgres') {
    return create_dbh_nonsqlite(
      $driver,
      name => 'foo',
      host => 'postgres',
      port => '5432',
      user => 'postgres',
      pass => 'password',
      driver => 'Pg',
    );
  }
  elsif ($driver eq 'oracle') {
    return create_dbh_nonsqlite(
      $driver,
      name => 'foo',
      host => 'oracle11',
      port => '1521',
      user => 'system',
      pass => 'oracle',
      driver => 'Oracle',
      sid => 'xe',
    );
  }

  die "Don't know how to build DBH for '$driver'\n";
}

sub table_sql {
  my ($driver, $dbh, $table, $defn) = @_;
  $driver = lc $driver;

  unless (exists $defn->{columns}) {
    $defn = {
      columns => $defn,
    };
  }

  my (@columns, @keys, @addl);
  my $sql = "CREATE TABLE `$table` (";
  if ($driver eq 'sqlite') {
    while (my ($col, $type) = each %{$defn->{columns}//{}}) {
      if ($type->{primary}) {
        push @columns, "`$col` INTEGER PRIMARY KEY AUTOINCREMENT";
      }
      elsif ($type->{foreign}) {
        push @columns, "`$col` INTEGER";
        my ($fk_table, $fk_col) = split('\.', $type->{foreign});
        push @keys, "FOREIGN KEY($col) REFERENCES $fk_table($fk_col)";
      }
      elsif ($type->{integer}) {
        push @columns, "`$col` INTEGER";
      }
      elsif ($type->{string}) {
        push @columns, "`$col` VARCHAR($type->{string})";
      }

      if ($type->{not_null}) {
        $columns[-1] .= " NOT NULL";
      }
    }
  }
  elsif ($driver eq 'mysql') {
    while (my ($col, $type) = each %{$defn->{columns}//{}}) {
      if ($type->{primary}) {
        push @columns, "`$col` INT NOT NULL PRIMARY KEY AUTO_INCREMENT";
      }
      elsif ($type->{foreign}) {
        push @columns, "`$col` INT";
        my ($fk_table, $fk_col) = split('\.', $type->{foreign});
        push @keys, "FOREIGN KEY (`$col`) REFERENCES $fk_table (`$fk_col`)";
      }
      elsif ($type->{integer}) {
        push @columns, "`$col` INT";
      }
      elsif ($type->{string}) {
        push @columns, "`$col` VARCHAR($type->{string})";
      }
      if ($type->{not_null}) {
        $columns[-1] .= " NOT NULL";
      }
    }
  }
  elsif ($driver eq 'postgres') {
    while (my ($col, $type) = each %{$defn->{columns}//{}}) {
      if ($type->{primary}) {
        push @columns, "$col SERIAL PRIMARY KEY";
      }
      elsif ($type->{foreign}) {
        push @columns, "$col INT";
        my ($fk_table, $fk_col) = split('\.', $type->{foreign});
        push @keys, "FOREIGN KEY ($col) REFERENCES $fk_table ($fk_col)";
      }
      elsif ($type->{integer}) {
        push @columns, "$col INT";
      }
      elsif ($type->{string}) {
        push @columns, "$col VARCHAR($type->{string})";
      }
      if ($type->{not_null}) {
        $columns[-1] .= " NOT NULL";
      }
    }
  }
  elsif ($driver eq 'oracle') {
    while (my ($col, $type) = each %{$defn->{columns}//{}}) {
      if ($type->{primary}) {
        push @columns, "$col INTEGER NOT NULL PRIMARY KEY";
        push @addl, "CREATE SEQUENCE ${table}_${col}_seq START WITH 1 INCREMENT BY 1";
        push @addl, "CREATE TRIGGER trg_${table}_${col}\n  BEFORE INSERT ON $table\n  FOR EACH ROW\nBEGIN\n  SELECT ${table}_${col}_seq.nextval into :new.${col} FROM dual;\nend;";
      }
      elsif ($type->{foreign}) {
        push @columns, "$col INTEGER";
        my ($fk_table, $fk_col) = split('\.', $type->{foreign});
        push @keys, "FOREIGN KEY ($col) REFERENCES $fk_table ($fk_col)";
      }
      elsif ($type->{integer}) {
        push @columns, "$col INT";
      }
      elsif ($type->{string}) {
        push @columns, "$col VARCHAR2($type->{string})";
      }
      if ($type->{not_null}) {
        $columns[-1] .= " NOT NULL";
      }
    }
  }
  # SQL Server: [ID] [int] IDENTITY(1,1) NOT NULL
  else {
    die "Don't know how to build SQL for '$driver'\n";
  }

  while (my ($name, $cols) = each %{$defn->{unique}//{}}) {
    # SQLite appends '_unique' to all UK constraint names. Therefore, do that
    # for all other drivers to keep the tests sane.
    if ($driver eq 'sqlite') {
      push @keys, "CONSTRAINT `$name` UNIQUE (`@{[join '`,`', @$cols]}`)";
    }
    elsif ($driver eq 'mysql') {
      push @keys, "UNIQUE KEY `${name}_unique` (`@{[join '`,`', @$cols]}`)";
    }
    elsif ($driver eq 'postgres') {
      push @keys, "CONSTRAINT ${name}_unique UNIQUE (@{[join ',', @$cols]})";
    }
    elsif ($driver eq 'oracle') {
      push @keys, "CONSTRAINT ${name}_unique UNIQUE (@{[join ',', @$cols]})";
    }
    else {
      die "Don't know how to build SQL for '$driver'\n";
    }
  }

  $sql .= join(',', @columns, @keys);

  $sql .= ");";

  # Postgres doesn't like backticks
  if ($driver eq 'postgres') {
    $sql =~ s/`//g;
  }
  # Oracle doesn't like backticks or semi-colons
  if ($driver eq 'oracle') {
    $sql =~ s/[`;]//g;
  }

  $dbh->do($sql);
  $dbh->do($_) for @addl;

  return $sql;
}

# Provide a clean wrapper around fork_subtest(). We need this because
# DBIC::DL expects to only be called once in a process per schema (for obvious
# and valid reasons). So, we need to run each test that would call DBIC::DL in
# its own process. This does add some overhead.
sub run_test ($$) {
  my ($name, $options) = @_;

  fork_subtest($name => sub {
    skip_all $options->{skip} if $options->{skip};

    my @parameters = (
      $options->{command},
    );

    if ($options->{driver}) {
      push @parameters, '--driver', $options->{driver};
    }

    if ($options->{database}) {
      # Provide a default database for tests that don't care.
      if ("$options->{database}" eq 'default') {
        $options->{database} = sub {
          my $dbh = shift;
          table_sql($options->{driver}, $dbh, foo => {
            id => { integer => 1 },
          });
        };
      }

      my ($dbh, $addl_params) = create_dbh($options);
      $options->{database}->($dbh);
      $dbh->disconnect;
      push @parameters, @$addl_params;
    }

    if ($options->{specification}) {
      my ($fh, $fn) = new_fh();
      print $fh Dump($options->{specification});
      close $fh;

      push @parameters, '--specification', $fn;
    }

    if ($options->{model}) {
      my ($fh, $fn) = new_fh();
      print $fh Dump($options->{model});
      close $fh;

      push @parameters, '--model', $fn;
    }

    # Allow specified parameters to override auto-generated parameters
    push @parameters, @{$options->{parameters} // []};

    my $result = test_app('App::SimsLoader' => \@parameters);

    foreach my $stream (qw(stdout stderr)) {
      $options->{$stream} //= '';

      if (ref($options->{$stream}) eq 'CODE') {
        ok($options->{$stream}->($result->$stream), uc($stream).' as expected');
      }
      # Is this something built with qr// ?
      elsif ("$options->{$stream}" =~ /^\(\?\^u?:.*\)$/) {
        like($result->$stream, $options->{$stream}, uc($stream).' as expected');
      }
      else {
        is($result->$stream, $options->{$stream}, uc($stream).' as expected');
      }
    }

    if (defined $options->{error}) {
      # Is this something built with qr// ?
      if ("$options->{error}" =~ /^\(\?\^u?:.*\)$/) {
        like($result->error, $options->{error}, 'Errors as expected');
      }
      else {
        is($result->error, $options->{error}, 'Errors as expected');
      }
    }
    else {
      is($result->error, undef, 'No errors (as expected)');
    }
  })->finish;
}

sub success ($$) {
  my ($name, $options) = @_;

  my %defaults = ();

  if ($options->{yaml_out}) {
    $defaults{stdout} = sub {
      my $stdout = shift;
      my $result = Load($stdout);
      like($result, $options->{yaml_out});
    };
  }

  run_test($name, {
    %defaults,
    %$options,
  });
}

1;
__END__
