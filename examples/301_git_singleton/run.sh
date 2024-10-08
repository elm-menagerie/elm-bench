#!/usr/bin/env bash
elm-bench -g HEAD -g tested-branch -g tested-tag -g main Remove.remove 42 "List.range 0 1000"
