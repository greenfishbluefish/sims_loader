# ABSTRACT: list all available drivers
package App::SimsLoader::Command::drivers;

use 5.20.0;
use strictures 2;

use base 'App::SimsLoader::Command';

my %skip = map { $_ => 1 } qw(
  DBD::DBM
  DBD::ExampleP
  DBD::File
  DBD::Gofer
  DBD::Metadata
  DBD::NullP
  DBD::Proxy
  DBD::Sponge
  DBD::SqlEngine
);

sub execute {
  chomp(my @modules = `cpan -l | grep 'DBD::'`);
  s/.*(DBD::[^:\s]*).*/$1/ for @modules;
  my %seen;
  foreach my $module (sort @modules) {
    next if $seen{$module}++;
    next if $skip{$module};
    $module =~ s/DBD:://;
    say $module;
  }
}

1;
__END__

