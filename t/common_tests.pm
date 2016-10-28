package # Hide from PAUSE
  t::common_tests;

use strictures 2;

use Test2::Bundle::Extended;

use File::Temp qw(tempdir);

use t::common qw(run_test);

use base 'Exporter';
our @EXPORT_OK = qw(
  failures_all_drivers
  failures_base_directory
  failures_connection
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

# The following assume they're within a subtest
sub failures_base_directory {
  my ($cmd, $driver) = @_;

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
}

sub failures_connection {
  my ($cmd, $driver) = @_;

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
  }
}
