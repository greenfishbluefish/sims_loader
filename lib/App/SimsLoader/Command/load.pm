# ABSTRACT: load your data
package App::SimsLoader::Command::load;

use 5.22.0;
use strictures 2;

use base 'App::SimsLoader::Command';

use App::SimsLoader::Loader;
use YAML::Any qw(Dump);

sub opt_spec {
  shift->opt_spec_for(qw(
    base_directory connection model load_sims
  )),
}

sub validate_args {
  my $self = shift;
  my ($opts, $args) = @_;

  $self->validate_driver($opts, $args);
  $self->validate_base_directory($opts, $args);
  $self->validate_connection($opts, $args);
  $self->validate_model_file($opts, $args);

  unless ($opts->{specification}) {
    $self->usage_error('Must provide --specification');
  }
  $self->{specification} = $self->find_file($opts, $opts->{specification})
    or $self->usage_error("--specification '$opts->{specification}' not found");

  $self->{spec} = $self->read_file($self->{specification})
    or $self->usage_error("--specification '$opts->{specification}' is not YAML/JSON");

  if (exists $opts->{seed}) {
    unless (($opts->{seed}//'') =~ /^\d\.\d+$/) {
      $self->usage_error("--seed '$opts->{seed}' is not legal");
    }
  }
}

sub execute {
  my $self = shift;
  my ($opts, $args) = @_;

  my $loader = $self->build_loader;

  my $addl_params = {};
  $addl_params->{seed} = $opts->{seed} if exists $opts->{seed};

  my ($rows, $addl) = $loader->load($self->{spec}, $addl_params);

  # Convert from DBIx::Class::Row objects to hashrefs
  foreach my $source (keys %$rows) {
    foreach my $row (@{$rows->{$source}}) {
      $row->discard_changes; # Force the row to reload itself.
      $row = { $row->get_columns };
    }
  }

  print Dump({
    seed => $addl->{seed},
    rows => $rows,
  });
}

1;
__END__
