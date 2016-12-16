package App::SimsLoader::Command;

use 5.22.0;

use strictures 2;

use App::Cmd::Setup -command;

use DBI;
use File::Spec ();
use JSON::Validator;
use Net::Telnet;
use YAML::Any qw(LoadFile);

# Don't quote numeric strings that haven't been numified.
$YAML::XS::QuoteNumericStrings = undef;

sub opt_spec {
  shift->opt_spec_for();
}

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

  if ($opts{model}) {
    push @specs, (
      [ 'model=s', "Model file" ],
    );
  }

  if ($opts{'model_detail'}) {
    push @specs, (
      [ 'name=s', "Model/Table for specific details" ],
    );
  }

  if ($opts{'load_sims'}) {
    push @specs, (
      [ 'specification=s', "Specification file" ],
      [ 'seed=s', "Initial seed" ],
    );
  }

  return @specs;
}

{
  # These are the drivers that come bundled with DBI that we do not want to
  # report as being available.
  my %skip = map { $_ => 1 } qw(
    DBM
    ExampleP
    File
    Gofer
    Proxy
    Sponge
  );

  sub find_dbds {
    sort {
      lc($a) cmp lc($b)
    } grep {
      !$skip{$_}
    } DBI->available_drivers;
  }
}

{
  my %perl_to_human = (
    Pg => 'postgres',
  );
  sub driver_to_human {
    shift;
    my ($proto) = @_;
    return lc($perl_to_human{$proto} || $proto);
  }

  # These aren't used right now. Comment them out until they are.
  #my %human_to_perl = reverse %perl_to_human;
  #sub driver_to_perl {
  #  shift;
  #  my ($proto) = @_;
  #  return $human_to_perl{lc($proto)} || $proto;
  #}
}

sub validate_driver {
  my $self = shift;
  my ($opts, $args) = @_;

  $self->usage_error('Must provide --driver') unless $opts->{driver};
  $opts->{driver} = lc $opts->{driver};

  my %dbds = map { $self->driver_to_human($_) => $_ } $self->find_dbds;
  unless ($dbds{lc($opts->{driver})}) {
    $self->usage_error("--driver '$opts->{driver}' not installed");
  }
  $self->{driver} = $dbds{lc($opts->{driver})};
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
  if ($self->{driver} eq 'SQLite') {
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

    # SQLite has two default tables: main.sqlite_master, temp.sqlite_temp_master
    my @tables = $dbh->tables();
    unless (@tables > 2) {
      $self->usage_error("Schema has no tables");
    }

    $self->{params} = {
      dbname => $dbname,
    };
  }
  # If we're not, validate we can connect to the host
  elsif ($self->{driver} eq 'mysql' || $self->{driver} eq 'Pg') {
    my $port = $opts->{port} // ($self->{driver} eq 'mysql' ? '3306' : '5432');

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
      my $cn = "dbi:$self->{driver}:host=$opts->{host};port=$port";
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

    my @tables = $dbh->tables();
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
    die "Cannot validate we can connect to $self->{driver}!\n";
  }
}

sub validate_model {
  my $self = shift;

  my $relationship_schema = {
    type => 'object',
    # These are the relationship names, validated by ::Loader
    additionalProperties => {
      type => 'object',
      required => ['columns', 'foreign'],
      properties => {
        # column names, validated by ::Loader
        columns => {
          type => 'array',
          items => { type => 'string' },
        },
        foreign => {
          type => 'object',
          required => ['source', 'columns'],
          properties => {
            source => { type => 'string' },
            # column names, validated by ::Loader
            columns => {
              type => 'array',
              items => { type => 'string' },
            },
          },
          additionalProperties => undef,
        },
      },
      additionalProperties => undef,
    },
  };

  my $schema = {
    type => 'object',
    # table names, validated by ::Loader
    additionalProperties => {
      type => 'object',
      properties => {
        # At least one of these must appear.
        anyOf => [
          { required => ['columns'] },
          { required => ['unique_constraints'] },
          { required => ['has_many'] },
          { required => ['belongs_to'] },
          { required => ['ignore'] },
        ],
        columns => {
          type => 'object',
          # column names, validated by ::Loader
          additionalProperties => {
            type => 'object',
            properties => {
              type => { type => 'string' },
              value => { type => 'string' },
            },
            minProperties => 1,
            maxProperties => 1,
          },
        },
        unique_constraints => {
          type => 'object',
          # unique constraint names, unvalidated
          additionalProperties => {
            type => 'array',
            # column names, validated by ::Loader
            items => { type => 'string' },
          },
        },
        has_many => $relationship_schema,
        belongs_to => $relationship_schema,
        ignore => {
          type => 'array',
          items => { type => 'string' },
        },
      },
      additionalProperties => undef,
    },
  };

  my $validator = JSON::Validator->new;
  $validator->schema($schema);
  my @errors = $validator->validate($self->{model});
  if (@errors) {
    $self->{errors} = join("\n\t", @errors);
    return;
  }

  return 1;
}

sub validate_model_file {
  my $self = shift;
  my ($opts, $args) = @_;

  if (exists $opts->{model}) {
    $self->{model_file} = $self->find_file($opts, $opts->{model})
      or $self->usage_error("--model '$opts->{model}' not found");

    $self->{model} = $self->read_file($self->{model_file})
      or $self->usage_error("--model '$opts->{model}' is not YAML/JSON");

    $self->validate_model
      or $self->usage_error("--model is invalid:\n\t$self->{errors}");
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

sub build_loader {
  my $self = shift;

  my $loader = eval {
    App::SimsLoader::Loader->new(
      type => $self->{driver},
      model => $self->{model} // {},
      %{$self->{params}},
    );
  }; if ($@) {
    $self->usage_error($@);
  }

  return $loader;
}

1;
__END__
