#!/usr/bin/env bash

# for every run.sh in this directory, run it
# (via find)
find . -name run.sh -execdir bash {} \;
