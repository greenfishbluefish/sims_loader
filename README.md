# Sims Loader

This will read an database, construct all the relationships, then take a minimal YAML specification and generate reasonable data (per your requirements) and load it into that database. You can set specific types for columns, add unique constraints, and use foreign key constraints, even if the schema doesn't have them (for whatever reasons).

# Running this program

## Pre-requisites

You will need to install Docker. This is the only requirement.

For most environments, install [Docker](https://docs.docker.com/engine/installation/). The instructions are pretty solid.

For Windows 7, you will need to install [Docker Toolbox](https://www.docker.com/products/docker-toolbox) instead of Docker. Once you have launched the Docker commandline (which launches `docker-machine`), you can use either that commandline or Git-Bash (described below). Once everything is done, there will be an executable called `docker` just like with Docker.

## Discussion

This is a commandline executable that is packaged and distributed within a Docker container. The best way to launch this program is to use a bash shell (on Windows, use Git-Bash, distributed with Git) and run the following bash script:
```bash
#!/bin/bash

MSYS_NO_PATHCONV=1 \
  docker run --rm \
    --volume $(pwd):/data \
    robkinyon/sims_loader:latest \
      $@
```

If you don't specify a command or options, it will default to `help`. (The MSYS\_NO\_PATHCONV environment variable is for users of Git-Bash and instructs Git-Bash to skip converting paths from Unix-like to Windows-like. It can be skipped on non-Git-Bash platforms.)

*Note:* All examples in this documentation will assume that you have the above saved as a bash script named `sims_loader` available in your current path. You may need to adjust examples accordingly.

### Docker Volumes

The use of a Docker volume is the only way I know of to share files betwen the host system and a container. As the Sims Loader needs up to 3 files available to it, mounting the current directory as a volume is the current solution. I will be exploring additional ways of communicating between the host and the container in future releases.

Please note that Docker will may or may not mount a NFS volume into a container and may or may not issue a warning or error about it. This all depends on your particular machine's setup, NFS setup, networking setup, and Docker version. If you receive an error of "file not found", please try copying the file to a directory physically on your machine and run again from within that directory.

### Docker Networking and localhost

If you are connecting to a database that is running somewhere other than your machine, use the same network address you would normally use.

However, if you are attempting to connect to a database running locally (such as for development or evaluation), you cannot use `127.0.0.1` or `localhost` - those will refer to the container itself. You also cannot use whatever 10.x.x.x, 172.x.x.x, or 192.168.x.x address you might normally use (or name that refers to such an address). Instead, you will need to provide an IP address according to the following rules:

* If you are using Docker Toolbox on either Windows or OSX (uses Virtualbox):
    * If you are connecting to a database on your host, use 10.0.2.2 (this is the IP address Virtualbox provides to connect to the host).
    * If you are connecting to a database in another container, use the value from `docker-machine ip`.
* If you are using Docker on Windows 10 (uses Hyper-V):
    * If you are connecting to a database on your host, use TBD.
    * If you are connecting to a database in another container, use TBD.
* If you are using Docker on OSX (uses xhyve):
    * If you are connecting to a database on your host, use TBD.
    * If you are connecting to a database in another container, use TBD.
* If you are using Docker on Linux (any distribution):
    * If you are connecting to a database on your host, use TBD.
    * If you are connecting to a database in another container, use TBD.

If you have a situation that isn't covered in the list above, please open an issue, hopefully with the right solution.

## Notes

The Docker container method of distribution is an experiment and subject to change as better methods appear.

Some users have reported that the download and installation of Docker Toolbox and the initial `docker pull` can take a significant amount of time. Future versions will attempt to address what can be done within this project.

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

Assume you have a database schema with two tables - invoices and lineitems. In MySQL, they could look something like:
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

To create 2 lineitems (without caring about the invoice), you would provide the following YAML file (in `specifications.yml`):
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

The output will be in YAML and describes the results.

# Purpose

Generating data for a non-trivial database is extremely hard, especially when dealing with lots of different foreign keys and application constraints that may not even be encoded (or encodable!) into the schema. There is a module in Perl called DBIx::Class::Sims (an extension to the Perl ORM DBIx::Class) which will generate usable randomized data with minimal fuss, but that requires you to use Perl *and* that specific ORM. Which isn't helpful for most projects.

Until now.

By marrying ::Sims with another DBIx::Class extension ::Schema::Loader, this tool will read your database's schema, decorate it with optional additional information you can specify, then write data into your database using whatever you have specified (ideally, the minimum possible).

# Sub-commands

## Connection parameters

The `model` and `load` sub-commands share a common set of parameters describing how to connect to the database. Some of these may be driver-specific.

Required:

* `--driver`: the database type. Use one of the values from the `drivers` sub-command.
* `--host`: the hostname of the database to connect to.
    * For the sqlite driver, this is the filename of the database.
* `--username`: the username to connect to the database with.
    * This is unused in the SQLite driver, but required otherwise.
* `--schema`: the schema to connect to within the database.
    * This is unused in the SQLite driver, but required otherwise.
    * This is unused in the Oracle driver, replaced by --sid

Optional:

* `--port` - If necessary, specify the port to connect with.
    * This is unused in the SQLite driver.
* `--password`: the password to connect to the database with.
    * If unprovided, no password with be set or passed to the connector.
    * This is unused in the SQLite driver.

Driver-specific options:

* `--sid`: the SID to connect to when connecting to Oracle.
    * This is required.

## Model file

In addition, the `model` and `load` sub-commands also take an optional `--model` parameter. This is a YAML file which is used to set additional configuration about your database and how you want Sims Loader to treat it. The YAML provided is an object whose keys are tablenames. The values are an object with configuration for that table. You can set the following configurations:

* columns
    * value (the specific value for this column)
    * values (an array of possible values for this column)
    * type (the Sims type for this column if no value is provided)
* unique\_constraints
    * This is an object with keys as constraint names and values as arrays of columns.
* belongs\_to / has\_many
    * These are objects with keys as relationship names and values as objects describing that relationship.
* ignore
    * This is an array of relationship names to ignore when determining the build order of the tables. q.v. "Generating Sims" for more information on when to use this.

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

This will provide all information that the Sims Loader has about the database you have connected to.

### Parameters

Required:

* Connection parameters

Optional:

* `--model`
* `--name`

### Output

If `--name` is not provided, then a list of all tables in the database you have connected to as a YAML array.

If `--name` is provided, then full details about the table requested, including:
* tablename
* columns
* relationships
* unique\_constraints

This will include anything specified by the `--model` file.

## load

This will load the requested rows (and all necessary parent rows) into the database you have connected to. More information about the specification file in the Generating Sims section.

### Parameters

Required:

* Connection parameters
* `--specification` - This is a YAML file containing the requested rows.

Optional:

* `--model`
* `--seed` - use the return value from a previous run to duplicate it.

### Output

This will return back information about the rows that were loaded as a YAML object. The output will contain the following keys:

* seed - this is the randomization seed to control what values are produced
* rows - this is an object containing the results of what was actually created.  The keys are the table names and the values are arrays of objects describing each new row.

# Generating Sims

All the rows are generated within a single transaction. (This can have consequences if thousands of rows are generated.) If any row fails to be created, then the entire transaction is rolled back and an appropriate error is reported.

## Sequence of Events

In order to ensure all parent rows are created before all child rows, a tree is created of the database tables, using foreign keys to determine parent-child relationships. If the foreign key relationships would create a cycle, you have to specify an `ignore` (q.v. "Model File") listing the relationships to ignore when constructing this tree. You can still use these relationships when constructing rows.

For each row requested in the specification, do the following steps:

0. Fill in all columns for the row, using rows in this order.
    * If column's value is specified, then use that.
    * Otherwise, if a column is a foreign key, find or create a row in the parent table and set the value of the column accordingly.
        * This is either the column or relationship name.
        * If nothing is specified about the parent, use any row that exists.
    * Otherwise, if a column has a `value` or `values` set, use that.
    * Otherwise, if a column has a `type` set, apply the type.
    * Otherwise, if the column is not nullable, generate a usable value based on if the column's type is string-like or number-like.
    * Otherwise, if the column is nullable, use NULL.
0. Attempt to see if there is a row that matches all unique constraints that have non-NULL values for all columns in the constraint.
    * If there is one, use that row instead.
0. Attempt to create the row.

This means each row is created singly. While slower, this is more correct and allows for better handling.

## Relationships

Every foreign key constraint has a relationship that can be used to name it.  This is normally the name of the anchoring column, but can be something else in the case of multi-column constraints. (This will be listed when getting the details of a table using `model --name <table>`.)

Using relationships makes your specifications much easier to maintain because the Sims is able to traverse the relationships and auto-generate the linking values. For example:

```
lineitems:
---
invoice:
  date: 2016-07-20 11:30:00
  account:
    number: 03-55-11253
    name: John Smith
amount: 4.31
item.name: Small Airplane
```

This will create a lineitem for an item with name "Small Airplane" that costs $4.31 on an invoice dated July 20th by an account for "John Smith" with a specific account number.

"item" and "invoice" are relationships to the items and invoices tables, respectively. "name" is a unique column on the items table, so just specifying that is sufficient to find or create it. If we have to create that item, then that table's columns will have Sims types set on them. For the invoice, there's a date and a foreign key again to the accounts table. `accounts.number` is a unique key. If the row doesn't exist, then it will be created and we want to set the `account.name` to "John Smith". (Note: If the row _does_ exist and the name isn't "John Smith", it won't be updated.)

Every other column in those tables and any other tables (like `addresses` or any lookup tables) that are needed to satisfy any other foreign keys will be auto-generated. They're not specified here because our use-case (like a test) doesn't care about those values.

# Contributing

This code is at https://github.com/greenfishbluefish/sims\_loader . This is also where issues should be reported. Pull requests are greatly appreciated.

## Running the tests

There is a docker-compose.yml file for running the test suite. This ensures the same environment for all test suite runners. This also provides and connects up all the databases necessary for the tests to run.

As a new database type is supported, it will be added to the docker-compose.

`./run_tests` will run everything. If you want to do anything more specific, youwill need to modify the docker-compose.yml file per the commented out section for entrypoint. The options are listed in the comments.

## Playing with the app

`./launch_container` will launch you into an interactive shell within the container. Within that shell, you can do a `carton run bin/sims_loader` to run the script.

This script is necessary because there isn't an interactive option for docker-compose on Windows.

## TODO list

A full TODO list is located in the GitHub repository. This list will be converted into GitHub issues in the near future.

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

This is free software, you may use it and distributed it under the same terms as Perl itself.
