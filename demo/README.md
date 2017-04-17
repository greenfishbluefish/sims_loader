# README #

This README would normally document whatever steps are necessary to get your application up and running.

## What is this repository for? ##

This contains the ICC demo(s) of [SimsLoader](https://hub.docker.com/r/robkinyon/sims_loader/).

## How do I get set up? ##

This demo consists of several Bash scripts and your favorite DB GUI viewer. These Bash scripts will provide a basic default setup.

On Windows, the Bash scripts are inteded to be run with [Git-Bash](https://git-for-windows.github.io/).

## The demo ##

The preparation for the demo consists of:
* [Installing Docker](https://docs.docker.com/engine/installation/)
    * On Windows before 10, install [Docker-Toolbox](https://www.docker.com/products/docker-toolbox).
* If necessary, [install Docker-Compose](https://docs.docker.com/compose/install/).
* Downloading the latest version of [SimsLoader](https://hub.docker.com/r/robkinyon/sims_loader/).
    * `docker pull robkinyon/sims_loader:latest`
    * This may take up to 20 minutes, depending on network performance.
* Starting a database server
    * If necessary, installling the server.
    * Launching the server. (q.v. below)
    * Creating the initial user and (if needed) the schema.

The demo consists of doing the following steps:

0. `./launch_mysql.sh`
0. Launch your GUI, pointed at the address given in `launch_mysql.sh`
0. Execute schema.sql
0. `./run_against_mysql.sh model`
0. `./run_against_mysql.sh model --name <name>`
0. `./run_against_mysql.sh load --specification file1.yml`
0. `./run_against_mysql.sh load --specification file1.yml --model model.yml`
  * New row, same address
0. Repeat with `--seed`
  * New row, same values, same address
0. `./run_against_mysql.sh load --specification file2.yml --model model.yml`
  * New row, new address
0. `./run_against_mysql.sh load --specification file3.yml --model model.yml`
  * 100 new rows, same address
0. Execute alter.sql
0. `./run_against_mysql.sh load --specification file1.yml`
  * See that the group table is simply linked to
0. `./run_against_mysql.sh load --model model.yml --specification file4.yml`
  * Demonstrate how a parent relationship can be traversed
  * Demonstrate the array of rows
  * Demonstrate the fact that a new row is created because existing rows are insufficient
0. `./run_against_mysql.sh load --model model.yml --specification file5.yml`
  * Demonstrate how a child relationship can be traversed
  * Demonstrate that only the row created is returned
  * Show the relationship name and how it does plural

### Contribution guidelines ###

* Writing tests
* Code review
* Other guidelines

### Who do I talk to? ###

* Repo owner or admin
* Other community or team contact
