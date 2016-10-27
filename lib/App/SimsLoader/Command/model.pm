# ABSTRACT: show the model of your database
package App::SimsLoader::Command::model;

use 5.20.0;
use strictures 2;

use base 'App::SimsLoader::Command';

use App::SimsLoader::Loader;
use YAML::Any qw(Dump);

sub opt_spec {
  my $self = shift;
  return (
    $self->SUPER::opt_spec,
    [ 'name=s', "Model/Table for specific details" ],
  );
}

sub validate_args {
  my $self = shift;
  my ($opts, $args) = @_;

  $self->SUPER::validate_args($opts, $args);

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
      };
      foreach my $col_name ($rsrc->columns) {
        $rv->{columns}{$col_name} = $rsrc->column_info($col_name);
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
