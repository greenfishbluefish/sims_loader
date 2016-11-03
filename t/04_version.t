use strictures 2;

use Test::More;
use t::common qw(run_test);

use App::SimsLoader;

# These are provided by App::Cmd, but it's a good idea to validate anyways.
run_test "version as subcommand" => {
  command => "version",
  stdout  => qr/version $App::SimsLoader::VERSION/,
};

run_test "version as parameter" => {
  command => "--version",
  stdout  => qr/version $App::SimsLoader::VERSION/,
};

done_testing;
