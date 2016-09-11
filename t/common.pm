package # Hide from PAUSE
  t::common;

use strictures 2;

use base 'Exporter';
our @EXPORT_OK = qw(
  new_fh
  sub_test
  success
);

use App::Cmd::Tester;
use DBI;
use File::Spec ();
use File::Temp qw( tempfile tempdir );
use Fcntl qw( :flock );
use Test2::Tools::AsyncSubtest;
use Test2::Bundle::Extended;
use YAML::Any qw(Dump);

my $parent = $ENV{WORK_DIR} || File::Spec->tmpdir;
our $dir = tempdir( CLEANUP => 1, DIR => $parent );

sub new_fh {
  my ($fh, $filename) = tempfile('tmpXXXX',
    DIR => $dir,
    EXLOCK => 0,
    UNLINK => 1,
  );

  # This is because tempfile() returns a flock'ed $fh on MacOSX.
  flock $fh, LOCK_UN;

  return ($fh, $filename);
}

# Provide a clean wrapper around fork_subtest(). We need this because
# DBIC::DL expects to only be called once in a process per schema (for obvious
# and valid reasons). So, we need to run each test that would call DBIC::DL in
# its own process. This does add some overhead.
sub sub_test ($$) {
  my ($name, $test) = @_;

  fork_subtest($name, $test)->finish;
}

sub success ($$) {
  my ($name, $options) = @_;

  sub_test $name => sub {
    my @parameters = (
      $options->{command},
      qw(--driver sqlite),
    );

    if ($options->{database}) {
      my ($fh, $fn) = new_fh();
      my $dbh = DBI->connect("dbi:SQLite:dbname=$fn", '', '');
      $options->{database}->($dbh);

      push @parameters, '--host', $fn;
    }

    if ($options->{specification}) {
      my ($fh, $fn) = new_fh();
      print $fh Dump($options->{specification});

      push @parameters, '--specification', $fn;
    }

    my $result = test_app('App::SimsLoader' => \@parameters);

    if ($options->{stdout}) {
      is($result->stdout, Dump($options->{stdout}), 'STDOUT of the row we created');
    }
    is($result->stderr, '', 'No STDERR (as expected)');
    is($result->error, undef, 'No errors thrown');
  };
}

1;
__END__
