# ABSTRACT: load your data
package App::SimsLoader::Command::load;

use 5.20.0;
use strictures 2;

use base 'App::SimsLoader::Command';

sub opt_spec {
  return (
    [ 'driver=s', "Driver name" ],
    [ 'host|h=s', "Host of database (or SQLite filename)" ],
  );
}

sub validate_args {
  my $self = shift;
  my ($opts, $args) = @_;

  $self->usage_error('Must provide --driver') unless $opts->{driver};

  my %dbds = map { lc($_) => 1 } App::SimsLoader::Command::drivers->find_dbds;
  $self->usage_error("--driver '$opts->{driver}' not installed")
    unless $dbds{lc($opts->{driver})};

  $self->usage_error('Must provide --host') unless $opts->{host};
}

sub execute {
  my $self = shift;
  my ($opts, $args) = @_;

}

1;
__END__
