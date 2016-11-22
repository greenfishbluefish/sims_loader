requires 'perl', '5.22.0';

requires 'DBIx::Class::Sims', '>= 0.300403';
requires 'DBIx::Class::Schema::Loader::Dynamic';
requires 'App::Cmd';
requires 'JSON::Validator';
requires 'Net::Telnet';

requires 'DBD::mysql';

on test => sub {
  requires 'Test::More', '>= 0.96, < 2.0';
  requires 'Test::Compile';
  requires 'Test::Deep';
  requires 'Devel::Cover';
  requires 'Test2::AsyncSubtest';
};
