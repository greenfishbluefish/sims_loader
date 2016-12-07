use 5.22.0;

use strictures 2;

use Test::More;
use t::common qw(drivers success);

use App::SimsLoader;

success "listing available drivers" => {
  command => 'drivers',
  stdout  => join("\n", sort(drivers())) . "\n",
};

done_testing;
