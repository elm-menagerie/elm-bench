module Foo exposing (scenario)

import MinPriorityQueue


scenario () =
    List.range 0 100
        |> MinPriorityQueue.fromList identity
        |> MinPriorityQueue.toList
