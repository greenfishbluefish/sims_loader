# ABSTRACT: show the model of your database
package App::SimsLoader::Command::model;

use 5.20.0;
use strictures 2;

use base 'App::SimsLoader::Command';

use App::SimsLoader::Loader;
use YAML::Any qw(LoadFile Dump);

sub opt_spec {
  return (
    [ 'driver=s', "Driver name" ],
    [ 'host|h=s', "Host of database (or SQLite filename)" ],
    [ 'base_directory=s', "Directory to find all files", {default => $ENV{SIMS_LOADER_BASE_DIRECTORY} // '.'} ],
    [ 'name=s', "Model/Table for specific details" ],
  );
}

sub validate_args {
  my $self = shift;
  my ($opts, $args) = @_;

  $self->usage_error('Must provide --driver') unless $opts->{driver};
  $opts->{driver} = lc $opts->{driver};

  my %dbds = map { lc($_) => $_ } App::SimsLoader::Command::drivers->find_dbds;
  unless ($dbds{lc($opts->{driver})}) {
    $self->usage_error("--driver '$opts->{driver}' not installed");
  }
  $opts->{driver} = $dbds{lc($opts->{driver})};

  unless (-d $opts->{base_directory}) {
    $self->usage_error("--base_directory '$opts->{base_directory}' is not a directory");
  }

  $self->usage_error('Must provide --host') unless $opts->{host};

  # If we're SQLite, validate the file exists
  if ($opts->{driver} eq 'SQLite') {
    $self->{host} = $self->find_file($opts, $opts->{host})
      or $self->usage_error("--host '$opts->{host}' not found");
  }
  # If we're not, validate we can connect to the host
  else {
    die "Unimplemented!\n";
  }

  # If $opts->{name}, validate it's a table or model we know about
}

sub execute {
  my $self = shift;
  my ($opts, $args) = @_;

  my $loader = App::SimsLoader::Loader->new(
    type => $opts->{driver},
    dbname => $self->{host},
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
