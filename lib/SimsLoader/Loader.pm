package SimsLoader::Loader;

use 5.22.0;

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
  $connectors //= '';

  my $connect_string = "dbi:$type:$connectors";

  my $schema = MySchema->connect($connect_string, '', '');
  DBIx::Class::Schema::Loader::Dynamic->new(
    naming => 'v8',
    use_namespaces => 0,
    schema => $schema,
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

1;
__END__
