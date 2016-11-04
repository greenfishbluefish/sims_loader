# ABSTRACT: list all available drivers
package App::SimsLoader::Command::drivers;

use 5.22.0;
use strictures 2;

use base 'App::SimsLoader::Command';

use DBI;

# These are the drivers that come bundled with DBI that we do not want to
# report as being available.
my %skip = map { $_ => 1 } qw(
  DBM
  ExampleP
  File
  Gofer
  Proxy
  Sponge
);

sub find_dbds {
  sort {
    lc($a) cmp lc($b)
  } grep {
    !$skip{$_}
  } DBI->available_drivers;
}

sub execute {
  say for find_dbds();
}

1;
__END__

