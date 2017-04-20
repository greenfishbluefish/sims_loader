use 5.22.0;

use strictures 2;

use Test::More;
use t::common qw(success);

use App::SimsLoader;

success "listing available types" => {
  command => 'types',
  stdout  => join("\n", sort qw(
    email_address ip_address
    us_firstname us_lastname us_name us_ssntin us_phone
    us_address us_city us_county us_state us_zipcode
    time date timestamp
    date_in_past date_in_past_N_years
    date_in_future date_in_next_N_years
    timestamp_in_past timestamp_in_past_N_years
    timestamp_in_future timestamp_in_next_N_years
  )) . "\n",
};

done_testing;
