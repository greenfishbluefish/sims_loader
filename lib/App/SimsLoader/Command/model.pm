# ABSTRACT: load your data
package App::SimsLoader::Command::model;

use 5.20.0;
use strictures 2;

use base 'App::SimsLoader::Command';

use App::SimsLoader::Loader;
use File::Spec ();
use YAML::Any qw(LoadFile Dump);

sub opt_spec {
  return (
    [ 'driver=s', "Driver name" ],
    [ 'host|h=s', "Host of database (or SQLite filename)" ],
    [ 'base_directory=s', "Directory to find all files", {default => $ENV{SIMS_LOADER_BASE_DIRECTORY} // '.'} ],
    #[ 'specification=s', "Specification file" ],
  );
}

sub find_file {
  my $self = shift;
  my ($opts, $filename) = @_;

  if (File::Spec->file_name_is_absolute($filename)) {
    return $filename if -f $filename;
    return;
  }

  my $path = File::Spec->join($opts->{base_directory}, $filename);
  return $path if -f $path;
  return;
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
    $opts->{host} = $self->find_file($opts, $opts->{host})
      || $self->usage_error("--host '$opts->{host}' not found");
  }
  # If we're not, validate we can connect to the host
  else {
    die "Unimplemented!\n";
  }
}

sub execute {
  my $self = shift;
  my ($opts, $args) = @_;

  my $loader = App::SimsLoader::Loader->new(
    type => $opts->{driver},
    dbname => $opts->{host},
  );

  my %response;
  foreach my $source ($loader->{schema}->sources) {
    my $rsrc = $loader->{schema}->source($source);
    $response{$source} = $rsrc->from;
  }

  print Dump(\%response);
}

1;
__END__
