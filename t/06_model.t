use strictures 2;

use Test2::Bundle::Extended;
use File::Temp qw(tempdir);

use App::SimsLoader;

use t::common qw(run_test success);
use t::common_tests qw(
  failures_all_drivers
  failures_base_directory
  failures_connection
);

my $cmd = 'model';

failures_all_drivers($cmd);

foreach my $driver (qw(sqlite mysql)) {
  subtest "Failures for $driver" => sub {
    failures_base_directory($cmd, $driver);
    failures_connection($cmd, $driver);
  };
}

foreach my $driver (qw(sqlite mysql)) {
  subtest "Successes for $driver" => sub {
    success "List all models" => {
      command => $cmd,
      driver => $driver,
      database => sub {
        my $dbh = shift;
        if ($driver eq 'sqlite') {
          $dbh->do('CREATE TABLE artists (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR)');
        }
        else {
          $dbh->do('CREATE TABLE artists (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(255))');
        }
      },
      yaml_out => {
        Artist => 'artists',
      },
    };

    success "Details of a specific model" => {
      command => $cmd,
      driver => $driver,
      parameters => [qw(
        --name artists
      )],
      database => sub {
        my $dbh = shift;
        if ($driver eq 'sqlite') {
          $dbh->do('CREATE TABLE artists (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(255) NOT NULL)');
        }
        else {
          $dbh->do('CREATE TABLE artists (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(255) NOT NULL)');
        }
      },
      yaml_out => {
        Artist => {
          table => 'artists',
          columns => {
            id => {
              data_type => 'integer',
              is_auto_increment => 1,
              is_nullable => 0,
            },
            name => {
              data_type => 'varchar',
              is_nullable => 0,
              size => 255,
            },
          },
        },
      },
    };
  };
}

done_testing;
