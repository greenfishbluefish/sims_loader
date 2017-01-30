requires 'perl', '5.22.1';

# Standard minimum necesssities
requires 'DateTime';
requires 'Sub::Identify';
requires 'Sub::Name';
requires 'List::MoreUtils';
requires 'Params::Util';
requires 'Params::Validate';

# Modules necessary for overall functionality
requires 'DBIx::Class::Sims', '>= 0.300501';
  requires 'Data::Compare'; # Needed for DBIC::Sims to install?
requires 'DBIx::Class::Schema::Loader::Dynamic';
requires 'App::Cmd';

# Modules necessary for basic functionality
requires 'JSON::Validator';
requires 'Net::Telnet';
requires 'YAML::XS';

########
# Modules necessary for each DBD

# SQLite
requires 'DBD::SQLite';

# MySQL
requires 'DBD::mysql';

# Postgres
requires 'DBD::Pg';
requires 'DateTime::Format::Pg';

# Oracle
requires 'DBD::Oracle';
requires 'DateTime::Format::Oracle';
requires 'Math::Base36', '>= 0.07';

# SQLServer
requires 'DBD::ODBC';
#
########

on test => sub {
  requires 'App::Cmd::Tester';
  requires 'Test2::Bundle::Extended';
  requires 'Test2::Tools::AsyncSubtest';
  requires 'Test::Compile';
  requires 'Devel::Cover';

  # Necessary for extra testing
  requires 'indirect';
  requires 'multidimensional';
  requires 'bareword::filehandles';
};
