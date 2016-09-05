use strictures 2;

use Test::More;
use App::Cmd::Tester;

use App::SimsLoader;

subtest "No parameters (failure)" => sub {
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

done_testing;
