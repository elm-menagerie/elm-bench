#!/usr/bin/env bash
elm-bench -j -f RemoveOld.remove -f RemoveNew.remove 42 "List.range 0 1000"
