package App::SimsLoader::Command;

use 5.22.0;

use strictures 2;

use App::Cmd::Setup -command;

use DBI;
use File::Spec ();
use Net::Telnet;
use YAML::Any qw(LoadFile);

# Don't quote numeric strings that haven't been numified.
$YAML::XS::QuoteNumericStrings = undef;

sub opt_spec_for {
  my $self = shift;
  my %opts = map { $_ => 1 } @_;

  my @specs;
  if ($opts{base_directory}) {
    push @specs, (
      [ 'base_directory=s', "Directory to find all files", {default => $ENV{SIMS_LOADER_BASE_DIRECTORY} // '.'} ],
    );
  }

  if ($opts{connection}) {
    push @specs, (
      [ 'driver|d=s', "Driver name" ],
      [ 'host|h=s', "Host of database (or SQLite filename)" ],
      [ 'port=s', "Port of database" ],
      [ 'schema=s', "Name of database schema" ],
      [ 'username|u=s', "Database user" ],
      [ 'password|P=s', "Database password" ],
    );
  }

  return @specs;
}

sub validate_driver {
  my $self = shift;
  my ($opts, $args) = @_;

  $self->usage_error('Must provide --driver') unless $opts->{driver};
  $opts->{driver} = lc $opts->{driver};

  my %dbds = map { lc($_) => $_ } App::SimsLoader::Command::drivers->find_dbds;
  unless ($dbds{lc($opts->{driver})}) {
    $self->usage_error("--driver '$opts->{driver}' not installed");
  }
  $opts->{driver} = $dbds{lc($opts->{driver})};
}

sub validate_base_directory {
  my $self = shift;
  my ($opts, $args) = @_;

  unless (-d $opts->{base_directory}) {
    $self->usage_error("--base_directory '$opts->{base_directory}' is not a directory");
  }
}

sub validate_connection {
  my $self = shift;
  my ($opts, $args) = @_;

  $self->usage_error('Must provide --host') unless $opts->{host};

  # If we're SQLite, validate the file exists
  if ($opts->{driver} eq 'SQLite') {
    my $dbname = $self->find_file($opts, $opts->{host})
      or $self->usage_error("--host '$opts->{host}' not found");

    my $dbh = eval {
      DBI->connect(
        "dbi:SQLite:dbname=$dbname", '', '', {
          PrintError => 0,
          RaiseError => 1,
        },
      );
    }; if ($@) {
      $self->usage_error("Cannot connect to database: $@");
    }

    my @tables = $dbh->tables('', '', 'TABLE');
    unless (@tables) {
      $self->usage_error("Schema has no tables");
    }

    $self->{params} = {
      dbname => $dbname,
    };
  }
  # If we're not, validate we can connect to the host
  elsif ($opts->{driver} eq 'mysql') {
    my $port = $opts->{port} // 3306;

    # Use Net::Telnet to determine if we can even connect to the database host.
    # This allows us to fail fast with a 1 second timeout.
    eval {
      Net::Telnet->new(
        -host => $opts->{host},
        -port => $port,
        -timeout => 1,
      );
    }; if ($@) {
      $self->usage_error("--host '$opts->{host}:$port' not found");
    }

    my $dbh = eval {
      my $cn = "dbi:mysql:host=$opts->{host};port=$port";
      $cn .= ";database=$opts->{schema}" if defined $opts->{schema};
      DBI->connect(
        $cn, $opts->{username} // '', $opts->{password} // '', {
          PrintError => 0,
          RaiseError => 1,
        },
      );
    }; if ($@) {
      if ($@ =~ /Access denied/) {
        $self->usage_error("Access denied for $opts->{username}");
      }
      elsif ($@ =~ /Unknown database/) {
        $self->usage_error("Unknown schema $opts->{schema}");
      }
      else {
        $self->usage_error("Cannot connect to database: $@");
      }
    }

    my @tables = $dbh->tables('', '', 'TABLE');
    unless (@tables) {
      $self->usage_error("Schema @{[$opts->{schema} // '']} has no tables");
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
}

sub find_file {
  my $self = shift;
  my ($opts, $filename) = @_;

  if (File::Spec->file_name_is_absolute($filename)) {
    return $filename if -f $filename;
    return;
  }

  my $path = File::Spec->join($opts->{base_directory}, $filename);
  return $path if -f $path && -r $path;
  return;
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

1;
__END__
