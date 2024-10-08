#!/usr/bin/env bash
elm-bench -f Remove.removeOld -f Remove.removeNew 42 "List.range 0 1000"
