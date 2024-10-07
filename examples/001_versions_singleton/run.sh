#!/usr/bin/env bash
elm-bench -v old -v new remove 42 "List.range 0 1000"
