package App::SimsLoader::Command;

use 5.20.0;

use strictures 2;

use App::Cmd::Setup -command;

use File::Spec ();

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

1;
__END__
