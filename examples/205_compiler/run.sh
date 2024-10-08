#!/usr/bin/env bash
elm-bench --compiler /Users/martinjaniczek/.volta/bin/elm -f RemoveOld.remove -f RemoveNew.remove 42 "List.range 0 1000"
