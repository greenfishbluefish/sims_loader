package # Hide from PAUSE
  t::common_tests;

use strictures 2;

use Test2::Bundle::Extended;

use File::Basename qw(basename dirname);
use File::Temp qw(tempdir);

use t::common qw(new_fh run_test);

use base 'Exporter';
our @EXPORT_OK = qw(
  failures_all_drivers
  failures_base_directory
  failures_connection
  failures_model_file
);

sub failures_all_drivers {
  my ($cmd) = @_;

  subtest "Failures - all drivers" => sub {
    run_test "No parameters" => {
      command => $cmd,
      error   => qr/Must provide --driver/,
    };

    run_test "--driver unknown" => {
      command => $cmd,
      driver  => 'unknown',
      error   => qr/--driver 'unknown' not installed/,
    };
  };
}

sub failures_base_directory {
  my ($cmd, $driver) = @_;

  subtest "$driver: Failures for base_directory" => sub {
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
  };
}

sub failures_connection {
  my ($cmd, $driver) = @_;

  subtest "$driver: Failures for connecting to database" => sub {
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

      run_test "--schema empty" => {
        command => $cmd,
        driver  => $driver,
        database => sub {},
        error   => qr{Schema has no tables},
      };
    }
    elsif ($driver eq 'mysql') {
      run_test "--host location not found (bad host)" => {
        command => $cmd,
        driver  => $driver,
        parameters => [qw(--host host.not.found)],
        error   => qr{--host 'host.not.found:3306' not found},
      };

      run_test "--host location not found (bad port)" => {
        command => $cmd,
        driver  => $driver,
        parameters => [qw(--host mysql --port 3307)],
        error   => qr{--host 'mysql:3307' not found},
      };

      run_test "--user invalid" => {
        command => $cmd,
        driver  => $driver,
        parameters => [qw(--host mysql --port 3306 --user not_here)],
        error   => qr{Access denied for not_here},
      };

      run_test "--password invalid" => {
        command => $cmd,
        driver  => $driver,
        database => sub {},
        parameters => [qw(--password bad)],
        error   => qr{Access denied for root},
      };

      run_test "--schema invalid" => {
        command => $cmd,
        driver  => $driver,
        database => sub {},
        parameters => [qw(--schema wrong)],
        error   => qr{Unknown schema wrong},
      };

      run_test "--schema empty" => {
        command => $cmd,
        driver  => $driver,
        database => sub {},
        error   => qr{Schema foo has no tables},
      };
    }
  };
}

sub failures_model_file {
  my ($cmd, $driver) = @_;

  subtest "$driver: Failures in the model file" => sub {
    run_test "--model file not found" => {
      command => $cmd,
      driver  => $driver,
      database => 'default',
      parameters => [
        '--model' => '/file/not/found',
      ],
      error => qr{--model '/file/not/found' not found},
    };

    run_test "--model file not found (bad base directory)" => {
      command => $cmd,
      driver  => $driver,
      database => 'default',
      parameters => [
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
          '--base_directory' => dirname($model_fn),
          '--model' => basename($model_fn),
        ],
        error => qr{--model '@{[basename($model_fn)]}' is not YAML/JSON},
      };
    }
  };
}
