# Processes

These are the processes necessary for managing this project. All commands are listed as if run within the git root (but all commands should be relocatable).

## run tests

0. `./run_tests`

This will pull and/or build any Docker images necessary.

## release a new version

0. Update the version number in lib/App/SimsLoader.pm
0. `docker login`
0. `./devops/packaging/build_all.sh`
0. Commit and push to master

## Update the Oracle client

0. Download the new Oracle RPMs from Oracle.
    * You will need to register a free account and manually download them.
    * You will need to download the basic, devel, and sqlplus RPMs.
        * SQL*Plus isn't *necessary*, but it's very helpful for debugging.
        * The JDBC RPM doesn't provide any value.
0. `MSYS_NO_PATHCONV=1 docker run -it --rm -v $(pwd):/app --entrypoint bash robkinyon/sims_loader -c bash`
    0. `cd /tmp`
        * `alien` will fail if run within a mounted volume because of permissions.
    0. `apt-get update`
    0. `apt-get install -y alien libaio-dev libaio1`
    0. `for r in /app/vendor/oracle/11.2/*.rpm; do echo $r; alien --to-deb --scripts $r; done`
        * Each one will take about a minute to convert.
    0. `mv *.deb /app/vendor/oracle/11.2`
0. Add and commit the debian files.
    * We keep the .rpm and .deb files committed to the repository.
