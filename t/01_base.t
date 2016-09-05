# This test ensures that all source files are going to be part of the coverage
# report, whether or not they're loaded by other tests. It also ensures we don't
# have any compilation errors in untested files.
use 5.20.0;
use strictures 2;

use Test::Compile;

my $test = Test::Compile->new;
$test->all_files_ok;
$test->done_testing;
