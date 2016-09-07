# ABSTRACT: load your data
package App::SimsLoader::Command::load;

use 5.20.0;
use strictures 2;

use base 'App::SimsLoader::Command';

sub opt_spec {
  return (
    [ 'driver=s', "Driver name" ],
    [ 'host|h=s', "Host of database (or SQLite filename)" ],
    [ 'base_directory=s', "Directory to find all files", {default => $ENV{SIMS_LOADER_BASE_DIRECTORY} // '.'} ],
    [ 'specification=s', "Specification file" ],
  );
}

sub find_file {
  my $self = shift;
  my ($opts, $filename) = @_;

  # If $filename is absolute, check -f
  # check -f $opts->{base_directory}/$filename
}

use YAML::Any qw(LoadFile Dump);
sub read_file {
  my $self = shift;
  my ($filename) = @_;

  my $x = eval {
    no warnings;
    return LoadFile($filename);
  }; if ($@) { say $@ }
  return $x if ref $x;
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

  $self->usage_error('Must provide --host') unless $opts->{host};

  # If we're SQLite, validate the file exists
  if ($opts->{driver} eq 'SQLite') {
    unless (-f $opts->{host}) {
      $self->usage_error("--host '$opts->{host}' not found");
    }
  }
  # If we're not, validate we can connect to the host
  else {
    die "Unimplemented!\n";
  }

  unless (-d $opts->{base_directory}) {
    $self->usage_error("--base_directory '$opts->{base_directory}' is not a directory");
  }

  unless ($opts->{specification}) {
    $self->usage_error('Must provide --specification');
  }
  unless (-f $opts->{specification}) {
    $self->usage_error("--specification '$opts->{specification}' not found");
  }

  $self->{spec} = $self->read_file($opts->{specification})
    or $self->usage_error("--specification '$opts->{specification}' is not YAML/JSON");
}

use App::SimsLoader::Loader;
sub execute {
  my $self = shift;
  my ($opts, $args) = @_;

  my $loader = App::SimsLoader::Loader->new(
    type => $opts->{driver},
    dbname => $opts->{host},
  );

  my ($rows, $addl) = $loader->load($self->{spec});

  # Convert from DBIx::Class::Row objects to hashrefs
  foreach my $source (keys %$rows) {
    foreach my $row (@{$rows->{$source}}) {
      $row = { $row->get_columns };
    }
  }

  print Dump($rows);
}

1;
__END__
