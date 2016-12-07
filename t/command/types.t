use 5.22.0;

use strictures 2;

use Test::More;
use t::common qw(success);

use App::SimsLoader;

success "listing available types" => {
  command => 'types',
  stdout  => join("\n", qw(
    email_address
    ip_address
    us_address
    us_city
    us_county
    us_firstname
    us_lastname
    us_name
    us_phone
    us_ssntin
    us_state
    us_zipcode
  )) . "\n",
};

done_testing;
