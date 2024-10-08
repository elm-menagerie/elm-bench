#!/usr/bin/env bash
elm-bench -f Main.removeOld -f Main.removeNew 42 "List.range 0 1000"
