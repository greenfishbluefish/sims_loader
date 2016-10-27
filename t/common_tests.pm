package # Hide from PAUSE
  t::common_tests;

use strictures 2;

use Test2::Bundle::Extended;

use t::common qw(run_test);

use base 'Exporter';
our @EXPORT_OK = qw(
  failures_all_drivers
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
