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
);

my $cmd = 'load';

failures_all_drivers($cmd);

foreach my $driver (drivers()) {
  subtest "Failures for $driver" => sub {
    failures_base_directory($cmd, $driver);
    failures_connection($cmd, $driver);

    #### --specification ####
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

    my ($spec_fh, $spec_fn) = new_fh();
    print $spec_fh "---\nArtist: 1\n";

    #### --model ####
    run_test "--model file not found" => {
      command => $cmd,
      driver  => $driver,
      database => 'default',
      parameters => [
        '--specification' => $spec_fn,
        '--model' => '/file/not/found',
      ],
      error => qr{--model '/file/not/found' not found},
    };

    run_test "--model file not found (bad base directory)" => {
      command => $cmd,
      driver  => $driver,
      database => 'default',
      parameters => [
        '--specification' => $spec_fn,
        '--base_directory' => tempdir(CLEANUP => 1),
        '--model' => 'file_not_found',
      ],
      error => qr{--model 'file_not_found' not found},
    };

    {
      my ($model_fh, $model_fn) = new_fh();
      print $model_fh "NOT YAML";
      run_test "--model file is not YAML/JSON" => {
        command => $cmd,
        driver  => $driver,
        database => 'default',
        parameters => [
          '--specification' => $spec_fn,
          '--model' => $model_fn,
        ],
        error => qr{--model '$model_fn' is not YAML/JSON},
      };
    }

    {
      my ($model_fh, $model_fn) = new_fh();
      print $model_fh "NOT YAML";
      run_test "--model file is not YAML/JSON (via base directory)" => {
        command => $cmd,
        driver  => $driver,
        database => 'default',
        parameters => [
          '--specification' => $spec_fn,
          '--base_directory' => dirname($model_fn),
          '--model' => basename($model_fn),
        ],
        error => qr{--model '@{[basename($model_fn)]}' is not YAML/JSON},
      };
    }
  };
}

foreach my $driver (drivers()) {
  success "$driver: Load one row specifying everything" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      shift->do(table_sql($driver, artists => {
        id => { primary => 1 },
        name => { string => 255 },
      }));
    },
    specification => {
      Artist => { name => 'George' },
    },
    yaml_out => {
      seed => D(),
      rows => {
        Artist => [
          { id => 1, name => 'George' },
        ],
      },
    },
  };

  success "$driver: Load two rows by asking for 2 rows" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      shift->do(table_sql($driver, artists => {
        id => { primary => 1 },
        name => { string => 255 },
      }));
    },
    specification => {
      Artist => 2,
    },
    yaml_out => {
      seed => D(),
      rows => {
        Artist => [
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
        shift->do(table_sql($driver, artists => {
          id => { primary => 1 },
          name => { string => 255, not_null => 1 },
        }));
      },
      specification => {
        Artist => 1,
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
            Artist => [
              { id => 1, name => D() },
            ],
          },
        });
        $name = $result->{rows}{Artist}[0]{name};
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
          Artist => [
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
      shift->do(table_sql($driver, artists => {
        id => { primary => 1 },
        name => { string => 255, not_null => 1 },
      }));
    },
    model => {
      Artist => {
        columns => {
          name => { value => 'George' },
        },
      },
    },
    specification => {
      Artist => 1,
    },
    yaml_out => {
      seed => D(),
      rows => {
        Artist => [
          { id => 1, name => 'George' },
        ],
      },
    },
  };
}

done_testing;
