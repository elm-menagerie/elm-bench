#!/usr/bin/env bash
# old-version | remove-old | f8a0681c8196c0d640f145938dbf8e33897a16f4
# master      | remove-new | b6be88de1ee5e3985338209b6fa37a4decc66b8c
rm -rf .git
git init .
git checkout -b master
mkdir -p src
cp RemoveOld.elm src/Remove.elm
git add src/Remove.elm
git commit -m "old"
HASH_OLD=$(git rev-parse HEAD)
git tag remove-old
git checkout -b old-version
git checkout master
cp RemoveNew.elm src/Remove.elm
git add src/Remove.elm
git commit -m "new"
HASH_NEW=$(git rev-parse HEAD)
git tag remove-new
elm-bench -g remove-old -g remove-new -g old-version -g master -g "$HASH_OLD" -g "$HASH_NEW" Remove.remove 42 "List.range 0 1000"
rm -rf .git
