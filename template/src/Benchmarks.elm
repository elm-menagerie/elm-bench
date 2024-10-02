port module Benchmarks exposing (main)

import Benchmark exposing (Benchmark)
import Benchmark.Alternative
import Benchmark.Runner.Cli
{{IMPORTS}}


port sendOutput : Benchmark.Runner.Cli.Output -> Cmd msg


main =
    Benchmark.Runner.Cli.program
        { suite = suite
        , sendOutput = sendOutput
        }


suite : Benchmark
suite =
    Benchmark.Alternative.rank
        "{{FUNCTION_NAME}}"
        (\f -> f {{ARGS}})
        {{VERSIONS}}


{{ARG_DEFS}}