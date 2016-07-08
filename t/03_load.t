use strictures 2;

use Test::More;
use App::Cmd::Tester;

use App::SimsLoader;

my $result = test_app('App::SimsLoader' => [qw( load )]);

is($result->stdout, "Hello\n", 'STDOUT as expected');
is($result->stderr, '', 'No STDERR (as expected)');
is($result->error, undef, 'No exceptions thrown');

done_testing;
