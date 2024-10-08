#!/usr/bin/env bash
elm-bench --compiler /Users/martin/.yarn/bin/elm -f RemoveOld.remove -f RemoveNew.remove 42 "List.range 0 1000"
