use 5.22.0;

use strictures 2;

use Test2::Bundle::Extended;

use App::SimsLoader;

use t::common qw(drivers table_sql run_test success);
use t::common_tests qw(
  failures_all_drivers
  failures_base_directory
  failures_connection
  failures_model_file
);

my $cmd = 'model';

failures_all_drivers($cmd);

foreach my $driver (drivers()) {
  failures_base_directory($cmd, $driver);
  failures_connection($cmd, $driver);
  failures_model_file($cmd, $driver);

  run_test "$driver: Source not found in model" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      shift->do(table_sql($driver, artists => {
        id => { primary => 1 },
      }));
    },
    model => {
      OtherTable => {},
    },
    error => qr/Cannot find OtherTable in database/,
  };

  run_test "$driver: Column not found in model" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      shift->do(table_sql($driver, artists => {
        id => { primary => 1 },
      }));
    },
    model => {
      Artist => { columns => { foo => {} } },
    },
    error => qr/Cannot find Artist.foo in database/,
  };
}

foreach my $driver (drivers()) {
  success "$driver: List all models" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      shift->do(table_sql($driver, artists => {
        id => { primary => 1 },
        name => { string => 255 },
      }));
    },
    yaml_out => {
      Artist => 'artists',
    },
  };

  success "$driver: Details of a disconnected model" => {
    command => $cmd,
    driver => $driver,
    parameters => [qw(
      --name artists
    )],
    database => sub {
      shift->do(table_sql($driver, artists => {
        id => { primary => 1 },
        name => { string => 255, not_null => 1 },
      }));
    },
    yaml_out => {
      Artist => {
        table => 'artists',
        columns => {
          id => {
            data_type => 'integer',
            is_auto_increment => 1,
            is_nullable => 0,
          },
          name => {
            data_type => 'varchar',
            is_nullable => 0,
            size => 255,
          },
        },
        relationships => {
        },
      },
    },
  };

  success "$driver: Two unconnected tables" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      my $dbh = shift;
      $dbh->do(table_sql($driver, artists => {
        id => { primary => 1 },
        name => { string => 255 },
      }));
      $dbh->do(table_sql($driver, studios => {
        id => { primary => 1 },
        name => { string => 255 },
      }));
    },
    yaml_out => {
      Artist => 'artists',
      Studio => 'studios',
    },
  };

  success "$driver: Two connected tables" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      my $dbh = shift;
      my $sql = table_sql($driver, artists => {
        id => { primary => 1 },
        name => { string => 255 },
      }); $dbh->do($sql) or die "$DBI::errstr\n\t$sql\n";
      $sql = table_sql($driver, studios => {
        id => { primary => 1 },
        artist_id => { foreign => 'artists.id' },
        name => { string => 255 },
      }); $dbh->do($sql) or die "$DBI::errstr\n\t$sql\n";
    },
    yaml_out => {
      Artist => 'artists',
      Studio => 'studios',
    },
  };

  success "$driver: Details of a parent model" => {
    command => $cmd,
    driver => $driver,
    parameters => [qw(
      --name artists
    )],
    database => sub {
      my $dbh = shift;
      my $sql = table_sql($driver, artists => {
        id => { primary => 1 },
        name => { string => 200 },
      }); $dbh->do($sql) or die "$DBI::errstr\n\t$sql\n";
      $sql = table_sql($driver, studios => {
        id => { primary => 1 },
        artist_id => { foreign => 'artists.id' },
        name => { string => 155 },
      }); $dbh->do($sql) or die "$DBI::errstr\n\t$sql\n";
    },
    yaml_out => {
      Artist => {
        table => 'artists',
        columns => {
          id => {
            data_type => 'integer',
            is_auto_increment => 1,
            is_nullable => 0,
          },
          name => {
            data_type => 'varchar',
            is_nullable => 1,
            size => 200,
          },
        },
        relationships => {
          studios => { has_many => 'Studio' },
        },
      },
    },
  };

  my %tests = ( source => 'Studio', table => 'studios' );
  while (my ($type, $value) = each %tests) {
    success "$driver: Details of a child model by $type name" => {
      command => $cmd,
      driver => $driver,
      parameters => [ '--name', $value ],
      database => sub {
        my $dbh = shift;
        my $sql = table_sql($driver, artists => {
          id => { primary => 1 },
          name => { string => 200 },
        }); $dbh->do($sql) or die "$DBI::errstr\n\t$sql\n";
        $sql = table_sql($driver, studios => {
          id => { primary => 1 },
          artist_id => { foreign => 'artists.id' },
          name => { string => 155 },
        }); $dbh->do($sql) or die "$DBI::errstr\n\t$sql\n";
      },
      yaml_out => {
        Studio => {
          table => 'studios',
          columns => {
            id => {
              data_type => 'integer',
              is_auto_increment => 1,
              is_nullable => 0,
            },
            name => {
              data_type => 'varchar',
              is_nullable => 1,
              size => 155,
            },
            artist_id => {
              data_type => 'integer',
              is_nullable => 1,
              is_foreign_key => 1,
            },
          },
          relationships => {
            artist => { belongs_to => 'Artist' },
          },
        },
      },
    };
  }

  success "$driver: Details of a model with a simmed value" => {
    command => $cmd,
    driver => $driver,
    parameters => [qw(
      --name artists
    )],
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
    yaml_out => {
      Artist => {
        table => 'artists',
        columns => {
          id => {
            data_type => 'integer',
            is_auto_increment => 1,
            is_nullable => 0,
          },
          name => {
            data_type => 'varchar',
            is_nullable => 0,
            size => 255,
            sim => {
              value => 'George',
            },
          },
        },
        relationships => {
        },
      },
    },
  };
}

done_testing;
