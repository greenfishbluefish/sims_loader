use 5.22.0;

use strictures 2;

use Test2::Bundle::Extended;

use App::SimsLoader;

use t::common qw(run_test);

my %defaults = (
  command  => 'model',
  driver   => 'sqlite',
  database => 'default',
);

run_test "model structure isn't a hash" => {
  %defaults,
  model => [],
  error => qr/--model is invalid:\n\t\/: Expected object - got array/,
};

run_test "model foo: aspect 'x' not found" => {
  %defaults,
  model => { foo => { x => 1 } },
  error => qr/--model is invalid:\n\t\/foo: Properties not allowed: x/,
};

done_testing;
