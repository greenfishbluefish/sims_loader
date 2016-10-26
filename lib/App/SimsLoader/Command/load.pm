# ABSTRACT: load your data
package App::SimsLoader::Command::load;

use 5.20.0;
use strictures 2;

use base 'App::SimsLoader::Command';

use App::SimsLoader::Loader;
use Net::Telnet;
use YAML::Any qw(LoadFile Dump);

# Don't quote numeric strings that haven't been numified.
$YAML::XS::QuoteNumericStrings = undef;

sub opt_spec {
  return (
    [ 'driver=s', "Driver name" ],
    [ 'host|h=s', "Host of database (or SQLite filename)" ],
    [ 'port=s', "Port of database" ],
    [ 'schema=s', "Name of database schema" ],
    [ 'username|u=s', "Database user" ],
    [ 'password=s', "Database password" ],
    [ 'base_directory=s', "Directory to find all files", {default => $ENV{SIMS_LOADER_BASE_DIRECTORY} // '.'} ],
    [ 'specification=s', "Specification file" ],
  );
}

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

  unless (-d $opts->{base_directory}) {
    $self->usage_error("--base_directory '$opts->{base_directory}' is not a directory");
  }

  $self->usage_error('Must provide --host') unless $opts->{host};

  # If we're SQLite, validate the file exists
  if ($opts->{driver} eq 'SQLite') {
    my $dbname = $self->find_file($opts, $opts->{host})
      or $self->usage_error("--host '$opts->{host}' not found");

    $self->{params} = {
      dbname => $dbname,
    };
  }
  # If we're not, validate we can connect to the host
  elsif ($opts->{driver} eq 'mysql') {
    my $port = $opts->{port} // 3306;
    eval {
      Net::Telnet->new(
        -host => $opts->{host},
        -port => $port,
        -timeout => 1,
      );
    }; if ($@) {
      $self->usage_error("--host '$opts->{host}:$port' not found");
    }

    $self->{params} = {
      host => $opts->{host},
      port => $port,
      username => $opts->{username} // '',
      password => $opts->{password} // '',
      database => $opts->{schema} // '',
    };
  }
  else {
    die "Unimplemented!\n";
  }

  unless ($opts->{specification}) {
    $self->usage_error('Must provide --specification');
  }
  $self->{specification} = $self->find_file($opts, $opts->{specification})
    or $self->usage_error("--specification '$opts->{specification}' not found");

  $self->{spec} = $self->read_file($self->{specification})
    or $self->usage_error("--specification '$opts->{specification}' is not YAML/JSON");
}

sub execute {
  my $self = shift;
  my ($opts, $args) = @_;

  my $loader = App::SimsLoader::Loader->new(
    type => $opts->{driver},
    %{$self->{params}},
  );

  my ($rows, $addl) = $loader->load($self->{spec});

  # Convert from DBIx::Class::Row objects to hashrefs
  foreach my $source (keys %$rows) {
    foreach my $row (@{$rows->{$source}}) {
      $row->discard_changes; # Force the row to reload itself.
      $row = { $row->get_columns };
    }
  }

  print Dump($rows);
}

1;
__END__
