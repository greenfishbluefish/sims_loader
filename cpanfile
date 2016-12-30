requires 'perl', '5.22.0';

# Modules necessary for overall functionality
requires 'DBIx::Class::Sims', '>= 0.300501';
  requires 'Data::Compare'; # Needed for DBIC::Sims to install?
requires 'DBIx::Class::Schema::Loader::Dynamic';
requires 'App::Cmd';

# Modules necessary for basic functionality
requires 'JSON::Validator';
requires 'Net::Telnet';

########
# Modules necessary for each DBD
# MySQL
requires 'DBD::mysql';

# Postgres
requires 'DBD::Pg';
requires 'DateTime::Format::Pg';

# Oracle
requires 'DBD::Oracle';
requires 'DateTime::Format::Oracle';
requires 'Math::Base36', '>= 0.07';
#
########

on test => sub {
  requires 'App::Cmd::Tester';
  requires 'Test2::Bundle::Extended';
  requires 'Test2::Tools::AsyncSubtest';
  requires 'Test::Compile';
  requires 'Devel::Cover';
};
