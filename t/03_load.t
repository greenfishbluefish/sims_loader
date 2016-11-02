use strictures 2;

use Test2::Bundle::Extended;
use File::Basename qw(basename dirname);
use File::Temp qw(tempdir);

use App::SimsLoader;

use t::common qw(new_fh table_sql success run_test);
use t::common_tests qw(
  failures_all_drivers
  failures_base_directory
  failures_connection
);

my $cmd = 'load';

failures_all_drivers($cmd);

foreach my $driver (qw(sqlite mysql)) {
  subtest "Failures for $driver" => sub {
    failures_base_directory($cmd, $driver);
    failures_connection($cmd, $driver);

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
  };
}

foreach my $driver (qw(sqlite mysql)) {
  subtest "Successes for $driver" => sub {
    success "Load one row specifying everything" => {
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
        Artist => [
          { id => 1, name => 'George' },
        ],
      },
    };

    success "Load two rows by asking for 2 rows" => {
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
        Artist => [
          { id => 1, name => undef },
          { id => 2, name => undef },
        ],
      },
    };

    success "Load one row with auto-gen name" => {
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
      yaml_out => {
        Artist => [
          { id => 1, name => D() },
        ],
      },
    };
  };
}

done_testing;
