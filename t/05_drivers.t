use strictures 2;

use Test::More;
use t::common qw(success);

use App::SimsLoader;

success "listing sqlite" => {
  command => 'drivers',
  stdout  => "SQLite\n",
};

done_testing;
