# ABSTRACT: list all available types
package App::SimsLoader::Command::types;

use 5.22.0;
use strictures 2;

use base 'App::SimsLoader::Command';

use DBIx::Class::Sims;

sub find_types {
  sort {
    lc($a) cmp lc($b)
  } DBIx::Class::Sims->sim_types;
}

sub execute {
  say for find_types();
}

1;
__END__

