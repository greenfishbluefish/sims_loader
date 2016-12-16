requires 'perl', '5.22.0';

# Modules necessary for overall functionality
requires 'DBIx::Class::Sims', '>= 0.300406';
requires 'DBIx::Class::Schema::Loader::Dynamic';
requires 'App::Cmd';

# Modules necessary for basic functionality
requires 'JSON::Validator';
requires 'Net::Telnet';

# Modules necessary for each DBD
requires 'DBD::mysql';

requires 'DBD::Pg';
requires 'DateTime::Format::Pg';

on test => sub {
  requires 'Test::More', '>= 0.96, < 2.0';
  requires 'Test::Compile';
  requires 'Test::Deep';
  requires 'Devel::Cover';
  requires 'Test2::AsyncSubtest';
};
