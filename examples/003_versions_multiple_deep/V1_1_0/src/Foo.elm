module Foo exposing (scenario)

import Usage.MinPriorityQueue


scenario () =
    List.range 0 100
        |> Usage.MinPriorityQueue.fromList identity
        |> Usage.MinPriorityQueue.toList
