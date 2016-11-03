# sims\_loader

A CLI for loading simulated data into any database using DBIx::Class plugins
Schema::Loader and Sims

# Examples

All of these examples assume the following parameters are provided:

    sims_loader -d <DB type> -h localhost -u my_user -PMyPassword

Loading data specified in a file

    sims_loader --specification my/spec/file.yml

Specifying additional relationships

    sims_loader --specification my/spec/file.yml --definition my/ddl/file.yml

# Purpose

Generating data for a non-trivial database is extremely hard, especially when
dealing with lots of different foreign keys and application constraints that may
not even be encoded (or encodable!) into the schema. There is a tool in Perl
called DBIx::Class::Sims (built using the Perl ORM DBIx::Class), but that
requires you to use Perl and that specific ORM. Which isn't helpful.

Until now.

By marrying ::Sims with another DBIx::Class extension ::Schema::Loader, this
tool will read your database's schema, decorate it with optional additional
information you can specify, then write data into your database using whatever
you have specified (ideally, the minimum possible).

# Details

TBD

# Usage

TBD

# Contributing

## Running the tests

There is a docker-compose.yml file for running the test suite. This ensures the
same environment for all test suite runners. This also provides and connects up
all the databases necessary for the tests to run.

### Running

`./run_tests` will run everything.

If you want to do anything more specific, you will need to modify the
docker-compose.yml file per the commented out section for entrypoint. The
options are listed in the comments.

### Useful Docker commands

* Remove all stopped containers:
  * `docker rm $(docker ps --no-trunc -aq)`
  * Useful after running the test suite multiple times.
* Remove all untagged images:
  * `docker rmi $(docker images | grep "^<none>" | awk '{print $3}')`
  * Useful if you built without tagging

## Playing with the app

`./launch_container` will launch you into an interactive shell within the
container. Within that shell, you can do a `carton run bin/sims_loader` to run
the script.

This script is necessary because there isn't an interactive option for
docker-compose on Windows.
