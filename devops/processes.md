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
