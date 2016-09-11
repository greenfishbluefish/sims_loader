use strictures 2;

use Test::More;
use App::Cmd::Tester;

use App::SimsLoader;

use t::common qw(new_fh success);

my $cmd = 'load';

subtest "Failures" => sub {
  subtest "No parameters" => sub {
    my $result = test_app('App::SimsLoader' => [$cmd]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr/Must provide --driver/, 'Error thrown about --driver');
  };

  subtest "Bad --driver" => sub {
    my $result = test_app('App::SimsLoader' => [$cmd, qw( --driver unknown )]);

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
    my $result = test_app('App::SimsLoader' => [$cmd, qw( --driver sqlite )]);

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

  subtest "No --specification" => sub {
    my ($host_fh, $host_fn) = new_fh();

    my $result = test_app('App::SimsLoader' => [$cmd, qw(
      --driver sqlite
      --host
    ), $host_fn ]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr{Must provide --specification}, 'Error thrown about --specification');
  };

  subtest "--specification file not found" => sub {
    my ($host_fh, $host_fn) = new_fh();

    my $result = test_app('App::SimsLoader' => [$cmd, qw(
      --driver sqlite
      --host), $host_fn, qw(
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

    my $result = test_app('App::SimsLoader' => [$cmd, qw(
      --driver sqlite
      --host), $host_fn, qw(
      --specification
    ), $spec_fn]);

    is($result->stdout, '', 'No STDOUT (as expected)');
    is($result->stderr, '', 'No STDERR (as expected)');
    like($result->error, qr{--specification '$spec_fn' is not YAML/JSON}, 'Error thrown about --specification');
  };
};

subtest "Successes" => sub {
  success "Load one row specifying everything" => {
    command => $cmd,
    database => sub {
      my $dbh = shift;
      $dbh->do('CREATE TABLE artists (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR)');
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
};

done_testing;
