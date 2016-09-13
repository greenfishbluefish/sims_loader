use strictures 2;

use Test::More;
use App::Cmd::Tester;
use File::Temp qw(tempdir);

use App::SimsLoader;

use t::common qw(new_fh run_test success);

my $cmd = 'model';

subtest "Failures" => sub {
  run_test "No parameters" => {
    command => $cmd,
    error   => qr/Must provide --driver/,
  };

  run_test "--driver unknown" => {
    command => $cmd,
    driver  => 'unknown',
    error   => qr/--driver 'unknown' not installed/,
  };

  run_test "--base_directory not a directory" => {
    command => $cmd,
    driver  => 'sqlite',
    parameters => [qw(--base_directory /not_a_directory)],
    error   => qr{--base_directory '/not_a_directory' is not a directory},
  };

  {
    local $ENV{SIMS_LOADER_BASE_DIRECTORY} = '/not_a_directory';
    run_test "SIMS_LOADER_BASE_DIRECTORY not a directory" => {
      command => $cmd,
      driver  => 'sqlite',
      error   => qr{--base_directory '/not_a_directory' is not a directory},
    };
  }

  run_test "No --host" => {
    command => $cmd,
    driver  => 'sqlite',
    error   => qr/Must provide --host/,
  };

  run_test "--host file not found" => {
    command => $cmd,
    driver  => 'sqlite',
    parameters => [qw(--host /file/not/found)],
    error   => qr{--host '/file/not/found' not found},
  };

  run_test "--host file not found (bad base_directory)" => {
    command => $cmd,
    driver  => 'sqlite',
    parameters => [qw(
      --host file_not_found
      --base_directory), tempdir(CLEANUP => 1),
    ],
    error   => qr{--host 'file_not_found' not found},
  };
};

subtest "Successes" => sub {
  success "List all models" => {
    command => $cmd,
    database => sub {
      my $dbh = shift;
      $dbh->do('CREATE TABLE artists (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR)');
    },
    yaml_out => {
      Artist => 'artists',
    },
  };

  success "Details of a specific model" => {
    command => $cmd,
    parameters => [qw(
      --name artists
    )],
    database => sub {
      my $dbh = shift;
      $dbh->do('CREATE TABLE artists (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)');
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
            data_type => 'text',
            is_nullable => 0,
          },
        },
      },
    },
  };
};

done_testing;
