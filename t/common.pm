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
  return qw(sqlite mysql);
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

sub create_dbh {
  my ($options) = @_;
  my $driver = $options->{driver} // 'sqlite';

  my ($dbh, @addl);
  if ($driver eq 'sqlite') {
    my ($fh, $fn) = new_fh();
    $dbh = DBI->connect("dbi:SQLite:dbname=$fn", '', '')
      or die "Cannot connect to $driver database: $DBI::errstr\n";
    push @addl, '--host', $fn;
  }
  elsif ($driver eq 'mysql') {
    my $dbname = 'foo';
    my $dbhost = 'mysql';
    my $dbport = '3306';
    my $dbuser = 'root';
    my $dbpass = '';

    my $conn = "host=$dbhost;port=$dbport";

    $dbh = DBI->connect("dbi:mysql:$conn", $dbuser, $dbpass)
      or die "Cannot connect to $driver database: $DBI::errstr\n";
    $dbh->do("DROP DATABASE IF EXISTS $dbname;");
    $dbh->do("CREATE DATABASE IF NOT EXISTS $dbname;");
    $dbh->disconnect;

    $conn .= ";database=$dbname";
    $dbh = DBI->connect("dbi:mysql:$conn", $dbuser, $dbpass)
      or die "Cannot connect to $driver database: $DBI::errstr\n";
    push @addl, '--host', $dbhost;
    push @addl, '--port', $dbport;
    push @addl, '--schema', $dbname;
    push @addl, '--username', $dbuser;
    push @addl, '--password', $dbpass;
  }
  else {
    die "Don't know how to build DBH for '$driver'\n";
  }

  return ($dbh, \@addl);
}

sub table_sql {
  my ($driver, $table, $defn) = @_;
  $driver = lc $driver;

  unless (exists $defn->{columns}) {
    $defn = {
      columns => $defn,
    };
  }

  my (@columns, @keys);
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
    else {
      die "Don't know how to build SQL for '$driver'\n";
    }
  }

  $sql .= join(',', @columns, @keys);

  $sql .= ");";

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
          shift->do(table_sql($options->{driver}, foo => {
            id => { integer => 1 },
          }));
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
      is($result, $options->{yaml_out});
    };
  }

  run_test($name, {
    %defaults,
    %$options,
  });
}

1;
__END__
