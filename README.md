# sims\_loader

A CLI for loading simulated data into any database using DBIx::Class plugins
Schema::Loader and Sims

# Examples

All of these examples assume the following parameters are provided:

    sims_loader -d <DB type> -h localhost -u my_user -PMyPassword

Loading data specified in a file

    sims_loader --spec my/spec/file.yml

Specifying additional relationships

    sims_loader --spec my/spec/file.yml --def my/ddl/file.yml

# Purpose

Generating data for a non-trivial database is extremely hard, especially when
dealing with lots of different foreign keys and application constraints that may
not even be encoded (or encodable!) into the schema. There is a tool in Perl
called DBIx::Class::Sims (built using the Perl ORM DBIx::Class), but that
requires you to use Perl and that specific ORM. Which isn't helpful.

Until now.

By marrying ::Sims with another DBIx::Class extension ::Schema::Loader, this
tool will read your database's schema, decorate it with optional additions you
can specify, then write data into your database using whatever you have
specified (ideally, the minimum possible).

# Running the tests

## Using Docker

There is a Dockerfile for running the test suite. This ensures the same
environment for all test suite runners.

### Initial steps

* `docker build -t sims_loader .`

You only need to do this once (or if any file within the devops directory
changes).

### Running

* With defaults (running prove):
  * `docker run -v $(pwd):/app -t sims_loader`
* To generate coverage
  * `docker run -v $(pwd):/app -t sims_loader cover`
* With prove options (like --verbose):
  * `docker run -v $(pwd):/app -t sims_loader prove <options>`
* To hop in and see what's going on:
  * `docker run -v $(pwd):/app -it sims_loader bash`
  * Note the `-it`: "-i" adds interactivity which the others do not have.

### Useful Docker commands

* Remove all stopped containers:
  * `docker rm $(docker ps --no-trunc -aq)`
  * Useful after running the test suite multiple times.
* Remove all untagged images:
  * `docker rmi $(docker images | grep "^<none>" | awk '{print $3}')`
  * Useful if you built without tagging

## Playing with the commands

Once you have launched the "bash" option of the sims\_loader container, you can
do a `carton run bin/sims_loader` to run the script.

# TODO

