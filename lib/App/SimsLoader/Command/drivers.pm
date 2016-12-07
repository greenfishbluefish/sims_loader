# ABSTRACT: list all available drivers
package App::SimsLoader::Command::drivers;

use 5.22.0;
use strictures 2;

use base 'App::SimsLoader::Command';

sub execute {
  my $self = shift;
  say for map { $self->driver_to_human($_) } $self->find_dbds();
}

1;
__END__

