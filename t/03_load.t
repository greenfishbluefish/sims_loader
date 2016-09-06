use strictures 2;

use Test::More;
use App::Cmd::Tester;

use App::SimsLoader;


use File::Spec ();
use File::Temp qw( tempfile tempdir );
use Fcntl qw( :flock );

my $parent = $ENV{WORK_DIR} || File::Spec->tmpdir;
our $dir = tempdir( CLEANUP => 1, DIR => $parent );

sub new_fh {
    my ($fh, $filename) = tempfile( 'tmpXXXX', DIR => $dir, UNLINK => 1 );

    # This is because tempfile() returns a flock'ed $fh on MacOSX.
    flock $fh, LOCK_UN;

    return ($fh, $filename);
}

subtest "Failures" => sub {
  subtest "No parameters" => sub {
    my $result = test_app('App::SimsLoader' => [qw( load )]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr/Must provide --driver/, 'Error thrown about --driver');
  };

  subtest "Bad --driver" => sub {
    my $result = test_app('App::SimsLoader' => [qw( load --driver unknown )]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr/--driver 'unknown' not installed/, 'Error thrown about --driver');
  };

  subtest "No --host" => sub {
    my $result = test_app('App::SimsLoader' => [qw( load --driver sqlite )]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr/Must provide --host/, 'Error thrown about --host');
  };

  subtest "--host file not found" => sub {
    my $result = test_app('App::SimsLoader' => [qw(load
      --driver sqlite
      --host /file/not/found
    )]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr{--host '/file/not/found' not found}, 'Error thrown about --host');
  };

  subtest "No --specification" => sub {
    my ($fh, $fn) = new_fh();

    my $result = test_app('App::SimsLoader' => [qw(load
      --driver sqlite
      --host
    ), $fn ]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr{Must provide --specification}, 'Error thrown about --specification');
  };

  subtest "--specification file not found" => sub {
    my $result = test_app('App::SimsLoader' => [qw(load
      --driver sqlite
      --host /etc/passwd
      --specification /file/not/found
    )]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr{--specification '/file/not/found' not found}, 'Error thrown about --specification');
  };

  subtest "--specification file is not YAML/JSON" => sub {
    my ($host_fh, $host_fn) = new_fh();
    my ($spec_fh, $spec_fn) = new_fh();
    print $spec_fh "NOT YAML";

    my $result = test_app('App::SimsLoader' => [qw(load
      --driver sqlite
      --host), $host_fn, qw(
      --specification
    ), $spec_fn]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr{--specification '$spec_fn' is not YAML/JSON}, 'Error thrown about --specification');
  };
};

use DBI;
use YAML::Any qw(Dump);
subtest "Successes" => sub {
  # Create a basic SQLite database
  subtest "Load one row" => sub {
    my ($db_fh, $db_fn) = new_fh();
    my $dbh = DBI->connect("dbi:SQLite:dbname=$db_fn", '', '');
    $dbh->do('CREATE TABLE artists (id INT PRIMARY KEY, name VARCHAR)');

    my ($spec_fh, $spec_fn) = new_fh();
    print $spec_fh "Artist:\n  name: George\n";
    #print $spec_fh "Artist: 1\n";

    my $result = test_app('App::SimsLoader' => [qw(load
      --driver sqlite
      --host), $db_fn, qw(
      --specification
    ), $spec_fn]);

    is($result->stdout, Dump({Artist => [{id => 1, name => 'George'}]}), 'STDOUT of the row we created');
    is($result->stderr, '', 'No STDERR (as expected)');
    is($result->error, undef, 'No errors thrown');
  };
};

done_testing;
