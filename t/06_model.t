use strictures 2;

use Test::More;
use App::Cmd::Tester;
use File::Temp qw(tempdir);

use App::SimsLoader;

use t::common qw(new_fh run_test success);
use t::common_tests qw(failures_all_drivers);

my $cmd = 'model';

failures_all_drivers($cmd);

foreach my $driver (qw(sqlite mysql)) {
  subtest "Failures for $driver" => sub {
    run_test "--base_directory not a directory" => {
      command => $cmd,
      driver  => $driver,
      parameters => [qw(--base_directory /not_a_directory)],
      error   => qr{--base_directory '/not_a_directory' is not a directory},
    };

    {
      local $ENV{SIMS_LOADER_BASE_DIRECTORY} = '/not_a_directory';
      run_test "SIMS_LOADER_BASE_DIRECTORY not a directory" => {
        command => $cmd,
        driver  => $driver,
        error   => qr{--base_directory '/not_a_directory' is not a directory},
      };
    }

    run_test "No --host" => {
      command => $cmd,
      driver  => $driver,
      error   => qr/Must provide --host/,
    };

    if ($driver eq 'sqlite') {
      run_test "--host file not found" => {
        command => $cmd,
        driver  => $driver,
        parameters => [qw(--host /file/not/found)],
        error   => qr{--host '/file/not/found' not found},
      };

      run_test "--host file not found (bad base_directory)" => {
        command => $cmd,
        driver  => $driver,
        parameters => [qw(
          --host file_not_found
          --base_directory), tempdir(CLEANUP => 1),
        ],
        error   => qr{--host 'file_not_found' not found},
      };
    }
    elsif ($driver eq 'mysql') {
      run_test "--host location not found (bad host)" => {
        command => $cmd,
        driver  => 'mysql',
        parameters => [qw(--host host.not.found)],
        error   => qr{--host 'host.not.found:3306' not found},
      };

      run_test "--host location not found (bad port)" => {
        command => $cmd,
        driver  => 'mysql',
        parameters => [qw(--host mysql --port 3307)],
        error   => qr{--host 'mysql:3307' not found},
      };
    }
  };
}

foreach my $driver (qw(sqlite mysql)) {
  subtest "Successes for $driver" => sub {
    success "List all models" => {
      command => $cmd,
      driver => $driver,
      database => sub {
        my $dbh = shift;
        if ($driver eq 'sqlite') {
          $dbh->do('CREATE TABLE artists (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR)');
        }
        else {
          $dbh->do('CREATE TABLE artists (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(255))');
        }
      },
      yaml_out => {
        Artist => 'artists',
      },
    };

    success "Details of a specific model" => {
      command => $cmd,
      driver => $driver,
      parameters => [qw(
        --name artists
      )],
      database => sub {
        my $dbh = shift;
        if ($driver eq 'sqlite') {
          $dbh->do('CREATE TABLE artists (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(255) NOT NULL)');
        }
        else {
          $dbh->do('CREATE TABLE artists (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(255) NOT NULL)');
        }
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
        },
      },
    };
  };
}

done_testing;
