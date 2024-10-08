#!/usr/bin/env bash
# old-version | remove-old | f8a0681c8196c0d640f145938dbf8e33897a16f4
# master      | remove-new | b6be88de1ee5e3985338209b6fa37a4decc66b8c
elm-bench -g remove-old -g remove-new -g old-version -g master -g f8a0681 -g b6be88d Remove.remove 42 "List.range 0 1000"
