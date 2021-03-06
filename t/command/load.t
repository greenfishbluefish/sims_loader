use 5.22.0;

use strictures 2;

use Test2::Bundle::Extended;
use File::Basename qw(basename dirname);
use File::Temp qw(tempdir);
use YAML::Any qw(Load);

use App::SimsLoader;

use t::common qw(drivers new_fh table_sql success run_test);
use t::common_tests qw(
  failures_all_drivers
  failures_base_directory
  failures_connection
  failures_model_file
);

my $cmd = 'load';

failures_all_drivers($cmd);

foreach my $driver (drivers()) {
  failures_base_directory($cmd, $driver);
  failures_connection($cmd, $driver);
  failures_model_file($cmd, $driver);

  subtest "$driver: Failures for --specification" => sub {
    run_test "--specification file not provided" => {
      command => $cmd,
      driver  => $driver,
      database => 'default',
      error => qr/Must provide --specification/,
    };

    run_test "--specification file not found" => {
      command => $cmd,
      driver  => $driver,
      database => 'default',
      parameters => [
        '--specification' => '/file/not/found',
      ],
      error => qr{--specification '/file/not/found' not found},
    };

    run_test "--specification file not found (bad base directory)" => {
      command => $cmd,
      driver  => $driver,
      database => 'default',
      parameters => [
        '--base_directory' => tempdir(CLEANUP => 1),
        '--specification'  => 'file_not_found',
      ],
      error => qr{--specification 'file_not_found' not found},
    };

    {
      my ($spec_fh, $spec_fn) = new_fh();
      print $spec_fh "NOT YAML";
      run_test "--specification file is not YAML/JSON" => {
        command => $cmd,
        driver  => $driver,
        database => 'default',
        parameters => [
          '--specification'  => $spec_fn,
        ],
        error => qr{--specification '$spec_fn' is not YAML/JSON},
      };
    }

    {
      my ($spec_fh, $spec_fn) = new_fh();
      print $spec_fh "NOT YAML";
      run_test "--specification file is not YAML/JSON (via base directory)" => {
        command => $cmd,
        driver  => $driver,
        database => 'default',
        parameters => [
          '--base_directory' => dirname($spec_fn),
          '--specification'  => basename($spec_fn),
        ],
        error => qr{--specification '@{[basename($spec_fn)]}' is not YAML/JSON},
      };
    }
  };
}

foreach my $driver (drivers()) {
  success "$driver: Load one row specifying everything" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      my $dbh = shift;
      table_sql($driver, $dbh, artists => {
        id => { primary => 1 },
        name => { string => 255 },
      });
    },
    specification => {
      artists => { name => 'George' },
    },
    yaml_out => {
      seed => D(),
      rows => {
        artists => [
          { id => 1, name => 'George' },
        ],
      },
    },
  };

  success "$driver: Load two rows by asking for 2 rows" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      my $dbh = shift;
      table_sql($driver, $dbh, artists => {
        id => { primary => 1 },
        name => { string => 255 },
      });
    },
    specification => {
      artists => 2,
    },
    yaml_out => {
      seed => D(),
      rows => {
        artists => [
          { id => 1, name => undef },
          { id => 2, name => undef },
        ],
      },
    },
  };

  subtest "$driver: See the same random value with a provided seed" => sub {
    my %common = (
      command => $cmd,
      driver => $driver,
      database => sub {
        my $dbh = shift;
        table_sql($driver, $dbh, artists => {
          id => { primary => 1 },
          name => { string => 255, not_null => 1 },
        });
      },
      specification => {
        artists => 1,
      },
    );

    my ($seed, $name);
    success "Load one row with auto-gen name" => {
      %common,
      stdout => sub {
        my $stdout = shift;
        my $result = Load($stdout);

        is($result, {
          seed => D(),
          rows => {
            artists => [
              { id => 1, name => D() },
            ],
          },
        });
        $name = $result->{rows}{artists}[0]{name};
        $seed = $result->{seed};
      },
    };

    success "Load a row with the same name" => {
      skip => "Cannot retrieve the \$name value from the forked subtest",
      %common,
      parameters => [qw(--seed), $seed],
      yaml_out => {
        seed => $seed,
        rows => {
          artists => [
            { id => 1, name => $name },
          ],
        },
      },
    };
  };

  success "$driver: add a simmed value" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      my $dbh = shift;
      table_sql($driver, $dbh, artists => {
        id => { primary => 1 },
        name => { string => 255, not_null => 1 },
      });
    },
    model => {
      artists => {
        columns => {
          name => { value => 'George' },
        },
      },
    },
    specification => {
      artists => 1,
    },
    yaml_out => {
      seed => D(),
      rows => {
        artists => [
          { id => 1, name => 'George' },
        ],
      },
    },
  };

  success "$driver: add an array of simmed values" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      my $dbh = shift;
      table_sql($driver, $dbh, artists => {
        id => { primary => 1 },
        name => { string => 255, not_null => 1 },
      });
    },
    model => {
      artists => {
        columns => {
          name => { values => [ 'George', 'Bob' ] },
        },
      },
    },
    specification => {
      artists => 1,
    },
    yaml_out => {
      seed => D(),
      rows => {
        artists => [
          { id => 1, name => match qr/^(?:George|Bob)$/ },
        ],
      },
    },
  };

  success "$driver: add a simmed type" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      my $dbh = shift;
      table_sql($driver, $dbh, artists => {
        id => { primary => 1 },
        name => { string => 255, not_null => 1 },
      });
    },
    model => {
      artists => {
        columns => {
          name => { type => 'us_firstname' },
        },
      },
    },
    specification => {
      artists => 1,
    },
    yaml_out => {
      seed => D(),
      rows => {
        artists => [
          { id => 1, name => match(qr/^\w+$/) },
        ],
      },
    },
  };

  success "$driver: handle a self-referential table" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      my $dbh = shift;
      table_sql($driver, $dbh, artists => {
        id => { primary => 1 },
        name => { string => 255, not_null => 1 },
        parent_id => { foreign => 'artists.id' },
      });
    },
    model => {
      artists => {
        ignore => ['parent'],
      },
    },
    specification => {
      artists => 1,
    },
    yaml_out => {
      seed => D(),
      rows => {
        artists => [
          { id => 1, name => match(qr/^\w+$/), parent_id => undef },
        ],
      },
    },
  };

  success "$driver: specify a simmed type" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      my $dbh = shift;
      table_sql($driver, $dbh, artists => {
        id => { primary => 1 },
        name => { string => 255, not_null => 1 },
      });
    },
    specification => "
    artists:
      name:
        type: us_firstname
    ",
    yaml_out => {
      seed => D(),
      rows => {
        artists => [
          { id => 1, name => match(qr/^\w+$/) },
        ],
      },
    },
  };
}

done_testing;
