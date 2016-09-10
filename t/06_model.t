use strictures 2;

use Test::More;
use App::Cmd::Tester;

use App::SimsLoader;

use t::common qw(new_fh);

my $cmd = 'model';

subtest "Failures" => sub {
  subtest "No parameters" => sub {
    my $result = test_app('App::SimsLoader' => [$cmd]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr/Must provide --driver/, 'Error thrown about --driver');
  };

  subtest "Bad --driver" => sub {
    my $result = test_app('App::SimsLoader' => [$cmd, qw(--driver unknown )]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr/--driver 'unknown' not installed/, 'Error thrown about --driver');
  };

  subtest "--base_directory not a directory" => sub {
    my $result = test_app('App::SimsLoader' => [$cmd, qw(
      --driver sqlite
      --base_directory /not_a_directory
    )]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr{--base_directory '/not_a_directory' is not a directory}, 'Error thrown about --base_directory');
  };

  subtest "SIMS_LOADER_BASE_DIRECTORY not a directory" => sub {
    local $ENV{SIMS_LOADER_BASE_DIRECTORY} = '/not_a_directory';

    my $result = test_app('App::SimsLoader' => [$cmd, qw(
      --driver sqlite
    )]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr{--base_directory '/not_a_directory' is not a directory}, 'Error thrown about --base_directory');
  };

  subtest "No --host" => sub {
    my $result = test_app('App::SimsLoader' => [$cmd, qw(--driver sqlite)]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr/Must provide --host/, 'Error thrown about --host');
  };

  subtest "--host file not found" => sub {
    my $result = test_app('App::SimsLoader' => [$cmd, qw(
      --driver sqlite
      --host /file/not/found
    )]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr{--host '/file/not/found' not found}, 'Error thrown about --host');
  };

  subtest "--host file not found (bad base_directory)" => sub {
    my $result = test_app('App::SimsLoader' => [$cmd, qw(
      --driver sqlite
      --host file_not_found
      --base_directory /tmp
    )]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr{--host 'file_not_found' not found}, 'Error thrown about --host');
  };
};

use DBI;
use YAML::Any qw(Dump);
subtest "list all models" => sub {
  my ($db_fh, $db_fn) = new_fh();
  my $dbh = DBI->connect("dbi:SQLite:dbname=$db_fn", '', '');
  $dbh->do('CREATE TABLE artists (id INT PRIMARY KEY, name VARCHAR)');

  my $result = test_app('App::SimsLoader' => [qw(model
    --driver sqlite
    --host), $db_fn,
  ]);

  is($result->stdout, Dump({Artist => 'artists'}), 'STDOUT of the schema');
  is($result->stderr, '', 'No STDERR (as expected)');
  is($result->error, undef, 'No errors thrown');
};

done_testing;
