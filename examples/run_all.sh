#!/usr/bin/env bash

# for every run.sh in this directory, run it
# (via find)
for x in ./*; do
  if [ ! -d "${x}" ]; then continue; fi
  cd "${x}";
  echo -e "\nRunning test: ${x}";
  ./run.sh
  cd ..
done;
