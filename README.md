# Sims Loader

This will read an database, construct all the relationships, then take a minimal
YAML specification and generate reasonable data (per your requirements) and loadit into that database. You can set specific types for columns, add unique
constraints, and use foreign key constraints, even if the schema doesn't have
them (for whatever reasons).

# Running this program

This is a commandline executable that is packaged and distributed within a
Docker container. The best way to launch this program is to use a bash shell (on
Windows, use Git-Bash, distributed with Git) and run the following bash script:
```bash
#!/bin/bash

MSYS_NO_PATHCONV=1 \
  docker run --rm \
    --volume $(pwd):/data \
    robkinyon/sims_loader:latest \
      $@
```
If you don't specify a command or options, it will default to `help`. (The
MSYS\_NO\_PATHCONV environment variable is for users of Git-Bash and instructs
Git-Bash to skip converting paths from Unix-like to Windows-like. It can be
skipped on non-Git-Bash platforms.)

*Note:* All examples in this documentation will assume that you have the above
saved as a bash script named `sims_loader` available in your current path. You
may need to adjust examples accordingly.

The use of a Docker volume is the only way I know of to share files betwen the
host system and a container. As the Sims Loader needs up to 3 files available to
it, mounting the current directory as a volume is the current solution. I will
be exploring additional ways of communicating between the host and the container
in future releases.

The Docker container method of distribution is an experiment and subject to
change as better methods appear.

# Summary

To list the available database drivers:
```bash
sims_loader drivers
```

To list which tables are available in a given schema:
```bash
sims_loader \
  model \
  --driver mysql --host my-db.company.com --username me --password S3kr3t \
```

To see the details about a specific table:
```bash
sims_loader \
  model \
  --driver mysql --host my-db.company.com --username me --password S3kr3t \
  --name some_table
```

To see the list of available Sims types:
```bash
sims_loader types
```

To load some data, assuming you have a specification file:
```bash
sims_loader \
  load \
  --driver mysql --host my-db.company.com --username me --password S3kr3t \
  --specification spec_file.yml
```

## Explanation

Assume you have a database schema with two tables - invoices and lineitems. In
MySQL, they could look something like:
```sql
CREATE TABLE invoices (
  invoice_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  description VARCHAR(255) NOT NULL,
  address1 VARCHAR(255) NOT NULL,
  city VARCHAR(255) NOT NULL,
  state VARCHAR(2) NOT NULL,
  zipcode VARCHAR(9) NOT NULL
);

CREATE TABLE lineitems (
  lineitem_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  description VARCHAR(255) NOT NULL,
  invoice_id INT NOT NULL REFERENCES invoices (invoice_id)
);
```

To create 2 lineitems (without caring about the invoice), you would provide the
following YAML file (in `specifications.yml`):
```yaml
---
lineitems: 2
```

You would then invoke the Sims Loader as so:
```bash
sims_loader \
  load \
  [ Your connection options ] \
  --specification specifications.yml
```

The output will be in YAML and describing your output.

# Purpose

Generating data for a non-trivial database is extremely hard, especially when
dealing with lots of different foreign keys and application constraints that may
not even be encoded (or encodable!) into the schema. There is a tool in Perl
called DBIx::Class::Sims (an extension to the Perl ORM DBIx::Class), but that
requires you to use Perl *and* that specific ORM. Which isn't helpful for most
projects.

Until now.

By marrying ::Sims with another DBIx::Class extension ::Schema::Loader, this
tool will read your database's schema, decorate it with optional additional
information you can specify, then write data into your database using whatever
you have specified (ideally, the minimum possible).

# Sub-commands

## Connection parameters

The `model` and `load` sub-commands share a common set of parameters describing
how to connect to the database. Some of these may be driver-specific.

Required:

* `--driver`: the database type. Use one of the values from the
`drivers` sub-command.
* `--host`: the hostname of the database to connect to.
    * For the sqlite driver, this is the filename of the database.
* `--username`: the username to connect to the database with.
    * This is unused in the SQLite driver, but required otherwise.
* `--schema`: the schema to connect to within the database.
    * This is unused in the SQLite driver, but required otherwise.

Optional:

* `--port` - If necessary, specify the port to connect with.
    * This is unused in the SQLite driver.
* `--password`: the password to connect to the database with.
    * If unprovided, no password with be set.
    * This is unused in the SQLite driver.

## Model file

In addition, the `model` and `load` sub-commands also take an optional `--model`
parameter. This is a YAML filename which is used to set additional configuration
about your database and you want Sims Loader to treat it. The YAML provided is
an object whose keys are tablenames. The values are an object with configuration
for that table. You can set the following configurations:

* columns
    * value (the specific value to default for this column)
    * type (the Sims type for this column if no value is provided)
* unique\_constraints
    * This is an object with keys as constraint names and values as arrays of
columns.
* belongs\_to
* has\_many

## drivers

This will list all pre-installed database drivers.

### Parameters

None

### Output

A list of database drivers, one per line.

## types

This will list all pre-installed Sims types.

### Parameters

None

### Output

A list of Sims types, one per line.

## model

This will provide all information that the Sims Loader has about the database
you have connected to.

### Parameters

Required:

* Connection parameters

Optional:

* `--model`
* `--name`

### Output

If `--name` is not provided, then a list of all tables in the database you have
connected to as a YAML array.

If `--name` is provided, then full details about the table requested, including:
* tablename
* columns
* relationships
* unique\_constraints

This will include anything specified by the `--model` file.

## load

This will load the requested rows (and all necessary parent rows) into the
database you have connected to.

### Parameters

Required:

* Connection parameters
* `--specification` - This is a YAML file containing the requested rows.

Optional:

* `--model`

### Output

This will return back information about the rows that were loaded as a YAML
object. The output will contain the following keys:

* seed
* rows

# Contributing

This code is at https://github.com/greenfishbluefish/sims\_loader . This is also
where issues should be reported. Pull requests are greatly appreciated.

## Running the tests

There is a docker-compose.yml file for running the test suite. This ensures the
same environment for all test suite runners. This also provides and connects up
all the databases necessary for the tests to run.

As a new database type is supported, it will be added to the docker-compose.

### Running

`./run_tests` will run everything.

If you want to do anything more specific, you will need to modify the
docker-compose.yml file per the commented out section for entrypoint. The
options are listed in the comments.

## Playing with the app

`./launch_container` will launch you into an interactive shell within the
container. Within that shell, you can do a `carton run bin/sims_loader` to run
the script.

This script is necessary because there isn't an interactive option for
docker-compose on Windows.

## TODO list

A full TODO list is located in the GitHub repository. This list will be
converted into GitHub issues in the near future.

## Useful Docker commands

* Remove all stopped containers:
  * `docker rm $(docker ps --no-trunc -aq)`
  * Useful after running the test suite multiple times.
* Remove all untagged images:
  * `docker rmi $(docker images | grep "^<none>" | awk '{print $3}')`
  * Useful if you built without tagging

# Author

Rob Kinyon <rob.kinyon@gmail.com>

# License

Copyright (c) 2016 Greenfish Bluefish, LLC. All Rights Reserved.
This is free software, you may use it and distributed it under the same terms as
Perl itself.
