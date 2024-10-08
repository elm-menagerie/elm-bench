#!/usr/bin/env bash
elm-bench --keep -f RemoveOld.remove -f RemoveNew.remove 42 "List.range 0 1000"
