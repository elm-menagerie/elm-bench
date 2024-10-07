#!/usr/bin/env bash
elm-bench -f Remove.remove -f Remove.New.remove 42 "List.range 0 1000"
