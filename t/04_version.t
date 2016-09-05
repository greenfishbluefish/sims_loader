use strictures 2;

use Test::More;
use App::Cmd::Tester;

use App::SimsLoader;

# These are provided by App::Cmd, but it's a good idea to validate anyways.

subtest "version as subcommand" => sub {
  my $result = test_app('App::SimsLoader' => [qw( version )]);

  like($result->stdout, qr/version $App::SimsLoader::VERSION/, 'STDOUT as expected');
  is($result->stderr, '', 'No STDERR (as expected)');
  is($result->error, undef, 'No exceptions thrown');
};

subtest "version as parameter" => sub {
  my $result = test_app('App::SimsLoader' => [qw( --version )]);

  like($result->stdout, qr/version $App::SimsLoader::VERSION/, 'STDOUT as expected');
  is($result->stderr, '', 'No STDERR (as expected)');
  is($result->error, undef, 'No exceptions thrown');
};

done_testing;
