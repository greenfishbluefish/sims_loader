# ABSTRACT: show the model of your database
package App::SimsLoader::Command::model;

use 5.22.0;
use strictures 2;

use base 'App::SimsLoader::Command';

use App::SimsLoader::Loader;
use YAML::Any qw(Dump);

sub opt_spec {
  shift->opt_spec_for(qw(
    base_directory connection model model_detail
  )),
}

sub validate_args {
  my $self = shift;
  my ($opts, $args) = @_;

  $self->validate_driver($opts, $args);
  $self->validate_base_directory($opts, $args);
  $self->validate_connection($opts, $args);
  $self->validate_model_file($opts, $args);

  # If $opts->{name}, validate it's a table or model we know about
}

sub execute {
  my $self = shift;
  my ($opts, $args) = @_;

  my $loader = $self->build_loader;

  my %response;
  my %sources = $loader->sources;
  if ($opts->{name}) {
    while (my ($name, $rsrc) = each %sources) {
      next unless lc($name) eq lc($opts->{name})
        || lc($rsrc->from) eq lc($opts->{name});

      $response{$name} = my $rv = {
        table => $rsrc->from,
        columns => {},
        relationships => {},
        unique_constraints => {},
      };
      foreach my $col_name ($rsrc->columns) {
        $rv->{columns}{$col_name} = $rsrc->column_info($col_name);
      }

      foreach my $rel_name ($rsrc->relationships) {
        my $info = $rsrc->relationship_info($rel_name);
        (my $other = $info->{class}) =~ s/MySchema:://;
        if ($info->{attrs}{accessor} eq 'single') {
          $rv->{relationships}{$rel_name} = { belongs_to => $other };
        }
        else {
          $rv->{relationships}{$rel_name} = { has_many => $other };
        }
      }

      my %uk = $rsrc->unique_constraints;
      while (my ($name, $cols) = each %uk) {
        $rv->{unique_constraints}{$name} = $cols;
      }
    }
  }
  else {
    while (my ($name, $rsrc) = each %sources) {
      $response{$name} = $rsrc->from;
    }
  }

  print Dump(\%response);
}

1;
__END__
