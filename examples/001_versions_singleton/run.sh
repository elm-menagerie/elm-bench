#!/usr/bin/env bash
elm-bench -v old -v new Main.remove 42 "List.range 0 1000"
