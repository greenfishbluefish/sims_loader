use strictures 2;

use Test::More;
use App::Cmd::Tester;

use App::SimsLoader;

subtest "listing sqlite" => sub {
  my $result = test_app('App::SimsLoader' => [qw( drivers )]);

  is($result->stdout, "SQLite\n", 'STDOUT as expected');
  is($result->stderr, '', 'No STDERR (as expected)');
  is($result->error, undef, 'No exceptions thrown');
};

done_testing;
