use strictures 2;

use Test2::Bundle::Extended;
use File::Basename qw(basename dirname);
use File::Temp qw(tempdir);

use App::SimsLoader;

use t::common qw(new_fh success run_test);

my $cmd = 'load';

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

  foreach my $driver (qw(sqlite mysql)) {
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

    run_test "--specification file not provided" => {
      command => $cmd,
      driver  => $driver,
      database => sub {},
      error   => qr/Must provide --specification/,
    };

    run_test "--specification file not found" => {
      command => $cmd,
      driver  => $driver,
      database => sub {},
      parameters => [
        '--specification' => '/file/not/found',
      ],
      error   => qr{--specification '/file/not/found' not found},
    };

    run_test "--specification file not found (bad base directory)" => {
      command => $cmd,
      driver  => $driver,
      database => sub {},
      parameters => [
        '--base_directory' => tempdir(CLEANUP => 1),
        '--specification'  => 'file_not_found',
      ],
      error   => qr{--specification 'file_not_found' not found},
    };

    {
      my ($spec_fh, $spec_fn) = new_fh();
      print $spec_fh "NOT YAML";
      run_test "--specification file is not YAML/JSON" => {
        command => $cmd,
        driver  => $driver,
        database => sub {},
        parameters => [
          '--specification'  => $spec_fn,
        ],
        error   => qr{--specification '$spec_fn' is not YAML/JSON},
      };
    }

    {
      my ($spec_fh, $spec_fn) = new_fh();
      print $spec_fh "NOT YAML";
      run_test "--specification file is not YAML/JSON (via base directory)" => {
        command => $cmd,
        driver  => $driver,
        database => sub {},
        parameters => [
          '--base_directory' => dirname($spec_fn),
          '--specification'  => basename($spec_fn),
        ],
        error   => qr{--specification '@{[basename($spec_fn)]}' is not YAML/JSON},
      };
    }
  }
};

foreach my $driver (qw(sqlite mysql)) {
  subtest "Successes for $driver" => sub {
    success "Load one row specifying everything" => {
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
      specification => {
        Artist => { name => 'George' },
      },
      yaml_out => {
        Artist => [
          { id => 1, name => 'George' },
        ],
      },
    };

=pod
    success "Load two rows by asking for 2 rows" => {
      command => $cmd,
      driver => $driver,
      database => sub {
        my $dbh = shift;
        $dbh->do('CREATE TABLE artists (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR)');
      },
      specification => {
        Artist => 2,
      },
      yaml_out => {
        Artist => [
          { id => 1, name => undef },
          { id => 2, name => undef },
        ],
      },
    };

    success "Load one row with auto-gen name" => {
      skip => "Doesn't work yet",
      command => $cmd,
      driver => $driver,
      database => sub {
        my $dbh = shift;
        $dbh->do('CREATE TABLE artists (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL)');
      },
      specification => {
        Artist => 1,
      },
      yaml_out => {
        Artist => [
          { id => 1, name => D() },
        ],
      },
    };
=cut
  };
}

done_testing;
