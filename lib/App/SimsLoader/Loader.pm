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
  my $self = shift;
  my ($model) = @_;

  my %skips = ();
  my %sim_types = map { lc($_) => 1 } App::SimsLoader::Command::types->find_types;
  while (my ($name, $source_mods) = each %$model) {
    my $rsrc = eval {
      $self->{schema}->source($name);
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
      elsif ($aspect eq 'belongs_to' || $aspect eq 'has_many') {
        while (my ($rel_name, $defn) = each %$data) {
          # Validate $defn->{columns}
          my @cols = @{$defn->{columns}};
          foreach my $col_name (@cols) {
            unless ($rsrc->has_column($col_name)) {
              die "Cannot find $name.$col_name in database\n";
            }
          }

          my $f_name = $defn->{foreign}{source};
          my $f_rsrc = eval {
            $self->{schema}->source($f_name);
          }; if ($@) {
            die "Cannot find $f_name in database\n";
          }

          # Validate $defn->{foreign}{columns}
          my @f_cols = @{$defn->{foreign}{columns}};
          foreach my $col_name (@f_cols) {
            unless ($f_rsrc->has_column($col_name)) {
              die "Cannot find $f_name.$col_name in database\n";
            }
          }

          # validate the number of columns is the same

          my %cond;
          foreach my $i (0 .. $#cols) {
            $cond{"foreign.$f_cols[$i]"} = "self.$cols[$i]";
          }

          my %attr;
          if ( $aspect eq 'belongs_to' ) {
            $attr{accessor} = 'single';
          }
          else {
            $attr{accessor} = 'multi';
            $attr{join_type} = 'left';
          }

          eval {
            $rsrc->add_relationship($rel_name, $f_name, \%cond, \%attr);
          }; if ($@) {
            die $@;
          }
        }
      }
      elsif ($aspect eq 'ignore') {
        push @{$skips{$name} //= []}, @$data;
      }
    }
  }

  $self->{toposort} = { skip => \%skips };

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
    if ($type eq 'Oracle' && ($k eq 'dbname' || $k eq 'database') ) {
      $k = 'sid';
    }
    push @connectors, "$k=$v";
  }
  my $connectors = join(';', @connectors);

  my $connect_string = "dbi:$type:$connectors";

  my $schema = MySchema->connect($connect_string, $user, $pass);
  DBIx::Class::Schema::Loader::Dynamic->new(
    # Force all table monikers to be the table name itself.
    moniker_map => sub { lc "$_[0]" },
    # Force all column accessors to be the column name itself.
    col_accessor_map => sub { "$_[0]" },
    # rel_name_map => sub {},
    naming => { relationships => 'v8' }, # Let's see if this is okay.
    use_namespaces => 0,
    schema => $schema,
  )->load;

  my $self = bless {
    schema => $schema,
  }, $class;

  $self->apply_model($model);

  return $self;
}

sub load {
  my $self = shift;
  my ($spec, $addl) = @_;
  $addl //= {};

  $addl->{toposort} = $self->{toposort} if $self->{toposort};

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
