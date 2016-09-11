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

  my @connectors;
  while (my ($k,$v) = each %opts) {
    push @connectors, "$k=$v";
  }
  my $connectors = join(';', @connectors);
  #$connectors //= '';

  my $connect_string = "dbi:$type:$connectors";

  my $schema = MySchema->connect($connect_string, '', '');
  DBIx::Class::Schema::Loader::Dynamic->new(
    naming => 'v8',
    use_namespaces => 0,
    schema => $schema,

    # Ignore the sqlite_master and sqlite_temp_master tables
    # XXX: Is this required? I cannot get a failing test for this even though
    # it used to be broken ... ?
    #exclude => qr/^sqlite_(master|temp)$/,
  )->load;

  return bless {
    schema => $schema,
  }, $class;
}

sub load {
  my $self = shift;
  my ($spec) = @_;

  $self->{schema}->load_sims($spec);
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
