package App::SimsLoader::Loader;

use 5.20.0;

use strictures 2;

use App::SimsLoader::Command::types;

use DBIx::Class::Schema::Loader::Dynamic;

{
  package MySchema;
  use strictures 2;
  use base 'DBIx::Class::Schema';
  __PACKAGE__->load_components('Sims');
}

sub apply_model {
  shift;
  my ($schema, $model) = @_;

  my %sim_types = map { lc($_) => 1 } App::SimsLoader::Command::types->find_types;
  while (my ($name, $source_mods) = each %$model) {
    my $rsrc = eval {
      $schema->source($name);
    }; if ($@) {
      die "Cannot find $name in database\n";
    }

    while (my ($aspect, $data) = each %$source_mods) {
      if ($aspect eq 'columns') {
        while (my ($col_name, $defn) = each %$data) {
          unless ($rsrc->has_column($col_name)) {
            die "Cannot find $name.$col_name in database\n";
          }

          if ($defn->{type}) {
            die "$name.$col_name: type $defn->{type} does not exist\n"
              unless $sim_types{$defn->{type}};
          }

          # The '+' modifies the existing column.
          $rsrc->add_column("+$col_name" => { sim => $defn });
        }
      }
      elsif ($aspect eq 'unique_constraints') {
        while (my ($key_name, $defn) = each %$data) {
          foreach my $col_name (@$defn) {
            unless ($rsrc->has_column($col_name)) {
              die "Cannot find $name.$col_name in database\n";
            }
          }
        }

        eval {
          $rsrc->add_unique_constraints(%{$data});
        }; if ($@) {
          die $@;
        }
      }
    }
  }
}

sub new {
  my $class = shift;
  my %opts = @_;

  my $type = delete $opts{type};
  my $model = delete $opts{model} // {};

  my $user = delete $opts{username} // '';
  my $pass = delete $opts{password} // '';

  my @connectors;
  while (my ($k,$v) = each %opts) {
    push @connectors, "$k=$v";
  }
  my $connectors = join(';', @connectors);
  #$connectors //= '';

  my $connect_string = "dbi:$type:$connectors";

  my $schema = MySchema->connect($connect_string, $user, $pass);
  DBIx::Class::Schema::Loader::Dynamic->new(
    # Force all table monikers to be the table name itself.
    moniker_map => sub { "$_[0]" },
    # Force all column accessors to be the column name itself.
    col_accessor_map => sub { "$_[0]" },
    # rel_name_map => sub {},
    naming => { relationships => 'v8' }, # Let's see if this is okay.
    use_namespaces => 0,
    schema => $schema,
  )->load;

  $class->apply_model($schema, $model);

  return bless {
    schema => $schema,
  }, $class;
}

sub load {
  my $self = shift;
  my ($spec, $addl) = @_;
  $addl //= {};

  $self->{schema}->load_sims($spec, $addl);
}

sub sources {
  my $self = shift;

  my %sources;
  foreach my $name ($self->{schema}->sources) {
    $sources{$name} = $self->{schema}->source($name);
  }

  return %sources;
}

1;
__END__
