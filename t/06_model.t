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

failures_all_drivers($cmd); # This takes 1

foreach my $driver (drivers()) {
  failures_base_directory($cmd, $driver); # This takes 2(sqlite, mysql)
  failures_connection($cmd, $driver); # This takes 4(sqlite), 7(mysql)
  failures_model_file($cmd, $driver); # This takes 4(sqlite, mysql)

  run_test "$driver: Source not found in model" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      shift->do(table_sql($driver, artists => {
        id => { primary => 1 },
      }));
    },
    model => {
      other_table => {},
    },
    error => qr/Cannot find other_table in database/,
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
      artists => { columns => { foo => { value => 'x' } } },
    },
    error => qr/Cannot find artists.foo in database/,
  };

  run_test "$driver: Type not found" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      shift->do(table_sql($driver, artists => {
        id => { primary => 1 },
        name => { string => 255 },
      }));
    },
    model => {
      artists => { columns => { name => { type => 'type_not_found' } } },
    },
    error => qr/artists.name: type type_not_found does not exist/,
  };

  run_test "$driver: Column not found for UK in model" => {
    command => $cmd,
    driver => $driver,
    database => sub {
      shift->do(table_sql($driver, artists => {
        id => { primary => 1 },
        name => { string => 255 },
      }));
    },
    model => {
      artists => { unique_constraints => { name => [qw( not_found )] } },
    },
    error => qr/Cannot find artists.not_found in database/,
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
      artists => 'artists',
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
      artists => {
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
        unique_constraints => { primary => [qw( id )] },
        relationships => {},
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
      artists => 'artists',
      studios => 'studios',
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
      artists => 'artists',
      studios => 'studios',
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
      artists => {
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
        unique_constraints => { primary => [qw( id )] },
        relationships => {
          studios => { has_many => 'studios' },
        },
      },
    },
  };

  success "$driver: Details of a child model by name" => {
    command => $cmd,
    driver => $driver,
    parameters => [qw(
      --name studios
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
      studios => {
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
        unique_constraints => { primary => [qw( id )] },
        relationships => {
          artist => { belongs_to => 'artists' },
        },
      },
    },
  };

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
      artists => {
        columns => {
          name => { value => 'George' },
        },
      },
    },
    yaml_out => {
      artists => {
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
        unique_constraints => { primary => [qw( id )] },
        relationships => {},
      },
    },
  };

  success "$driver: Details of a model with a simmed type" => {
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
      artists => {
        columns => {
          name => { type => 'us_firstname' },
        },
      },
    },
    yaml_out => {
      artists => {
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
              type => 'us_firstname',
            },
          },
        },
        unique_constraints => { primary => [qw( id )] },
        relationships => {},
      },
    },
  };

  success "$driver: Details of a model with a unique key" => {
    command => $cmd,
    driver => $driver,
    parameters => [qw(
      --name artists
    )],
    database => sub {
      shift->do(table_sql($driver, artists => {
        columns => {
          id => { primary => 1 },
          name => { string => 255, not_null => 1 },
        },
        unique => {
          name => [qw( name )],
        },
      }));
    },
    yaml_out => {
      artists => {
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
        relationships => {},
        unique_constraints => {
          primary => [qw( id )],
          name_unique => [qw( name )],
        },
      },
    },
  };

  success "$driver: Details of a model with an added unique key" => {
    command => $cmd,
    driver => $driver,
    parameters => [qw(
      --name artists
    )],
    database => sub {
      shift->do(table_sql($driver, artists => {
        columns => {
          id => { primary => 1 },
          name => { string => 255, not_null => 1 },
        },
      }));
    },
    model => {
      artists => {
        unique_constraints => {
          name => [qw( name )],
        },
      },
    },
    yaml_out => {
      artists => {
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
        relationships => {},
        unique_constraints => {
          primary => [qw( id )],
          name => [qw( name )],
        },
      },
    },
  };

  success "$driver: Details of a parent model with an added relationship" => {
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
        artist_id => { integer => 1 },
        name => { string => 155 },
      }); $dbh->do($sql) or die "$DBI::errstr\n\t$sql\n";
    },
    model => {
      artists => {
        has_many => {
          studios => {
            columns => [ 'id' ],
            foreign => {
              source  => 'studios',
              columns => [ 'artist_id' ],
            },
          },
        },
      },
    },
    yaml_out => {
      artists => {
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
        unique_constraints => { primary => [qw( id )] },
        relationships => {
          studios => { has_many => 'studios' },
        },
      },
    },
  };

  success "$driver: Details of a child model with an added relationship" => {
    command => $cmd,
    driver => $driver,
    parameters => [qw(
      --name studios
    )],
    database => sub {
      my $dbh = shift;
      my $sql = table_sql($driver, artists => {
        id => { primary => 1 },
        name => { string => 200 },
      }); $dbh->do($sql) or die "$DBI::errstr\n\t$sql\n";
      $sql = table_sql($driver, studios => {
        id => { primary => 1 },
        artist_id => { integer => 1 },
        name => { string => 155 },
      }); $dbh->do($sql) or die "$DBI::errstr\n\t$sql\n";
    },
    model => {
      studios => {
        belongs_to => {
          artist => {
            columns => [ 'artist_id' ],
            foreign => {
              source  => 'artists',
              columns => [ 'id' ],
            },
          },
        },
      },
    },
    yaml_out => {
      studios => {
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
          },
        },
        unique_constraints => { primary => [qw( id )] },
        relationships => {
          artist => { belongs_to => 'artists' },
        },
      },
    },
  };
}

done_testing;
