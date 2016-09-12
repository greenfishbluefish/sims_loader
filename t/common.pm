package # Hide from PAUSE
  t::common;

use strictures 2;

use base 'Exporter';
our @EXPORT_OK = qw(
  new_fh
  run_test
  success
);

# Load this here to avoid warnings re: Test2
use Test::Builder;

use App::Cmd::Tester;
use DBI;
use File::Spec ();
use File::Temp qw( tempfile tempdir );
use Fcntl qw( :flock );
use Test2::Bundle::Extended;
use Test2::Tools::AsyncSubtest;
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
sub run_test ($$) {
  my ($name, $options) = @_;

  fork_subtest($name => sub {
    skip_all $options->{skip} if $options->{skip};

    my @parameters = (
      $options->{command},
      @{$options->{parameters} // []},
    );

    if ($options->{driver}) {
      push @parameters, '--driver', $options->{driver};
    }

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

    foreach my $stream (qw(stdout stderr)) {
      $options->{$stream} //= '';

      # Is this something built with qr// ?
      if ("$options->{$stream}" =~ /^\(\?\^:.*\)$/) {
        like($result->$stream, $options->{$stream}, uc($stream).' as expected');
      }
      else {
        is($result->$stream, $options->{$stream}, uc($stream).' as expected');
      }
    }

    if (defined $options->{error}) {
      if ("$options->{error}" =~ /^\(\?\^:.*\)$/) {
        like($result->error, $options->{error}, 'Errors as expected');
      }
      else {
        is($result->error, $options->{error}, 'Errors as expected');
      }
    }
    else {
      is($result->error, undef, 'No errors (as expected)');
    }
  })->finish;
}

sub success ($$) {
  my ($name, $options) = @_;

  my %defaults = (
    driver => 'sqlite',
  );

  if ($options->{yaml_out}) {
    $defaults{stdout} = Dump(delete $options->{yaml_out});
  }

  run_test($name, {
    %defaults,
    %$options,
  });
}

1;
__END__
