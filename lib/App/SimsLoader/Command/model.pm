# ABSTRACT: show the model of your database
package App::SimsLoader::Command::model;

use 5.22.0;
use strictures 2;

use base 'App::SimsLoader::Command';

use App::SimsLoader::Loader;
use YAML::Any qw(Dump);

sub opt_spec {
  my $self = shift;
  return (
    $self->opt_spec_for(qw(
      base_directory connection
    )),
    [ 'name=s', "Model/Table for specific details" ],
  );
}

sub validate_args {
  my $self = shift;
  my ($opts, $args) = @_;

  $self->validate_driver($opts, $args);
  $self->validate_base_directory($opts, $args);
  $self->validate_connection($opts, $args);

  # If $opts->{name}, validate it's a table or model we know about
}

sub execute {
  my $self = shift;
  my ($opts, $args) = @_;

  my $loader = App::SimsLoader::Loader->new(
    type => $opts->{driver},
    %{$self->{params}},
  );

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
      };
      foreach my $col_name ($rsrc->columns) {
        $rv->{columns}{$col_name} = $rsrc->column_info($col_name);
      }

      foreach my $rel_name ($rsrc->relationships) {
        my $info = $rsrc->relationship_info($rel_name);
        #$rv->{relationships}{$rel_name} = $info;
        (my $other = $info->{class}) =~ s/MySchema:://;
        if ($info->{attrs}{accessor} eq 'single') {
          $rv->{relationships}{$rel_name} = { belongs_to => $other };
        }
        else {
          $rv->{relationships}{$rel_name} = { has_many => $other };
        }
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
