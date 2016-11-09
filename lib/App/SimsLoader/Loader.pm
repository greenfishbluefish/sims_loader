package App::SimsLoader::Loader;

use 5.20.0;

use strictures 2;

use DBIx::Class::Schema::Loader::Dynamic;

{
  package MySchema;
  use strictures 2;
  use base 'DBIx::Class::Schema';
  __PACKAGE__->load_components('Sims');
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
    naming => 'v8',
    use_namespaces => 0,
    schema => $schema,
  )->load;

  while (my ($name, $source_mods) = each %$model) {
    # This needs to allow both table and model names.
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

          # The '+' modifies the existing column.
          $rsrc->add_column("+$col_name" => { sim => $defn });
        }
      }
    }
  }

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
