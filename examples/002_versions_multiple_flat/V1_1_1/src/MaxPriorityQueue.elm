module MaxPriorityQueue exposing
    ( MaxPriorityQueue
    , empty, singleton, fromList
    , toList, toSortedList, fold
    , insert, enqueue, filter, dequeue, dequeueMany, largest, head, tail, take, drop
    , all, any, isEmpty, length
    )

{-| The `(a -> Int)` function given to `singleton`, `insert`, `enqueue` and `fromList`
is how you teach the queue to get the priority of an item. `MaxPriorityQueue` will
prioritize items with larger Ints.

@docs MaxPriorityQueue

**Note:** Some functions in this module return lists of values in perhaps a slightly
unexpected reversed order (`toSortedList`, `dequeueMany`, `take`). This is done
in name of efficiency: there's no trick to efficiently return it in the more
expected reverse order, so we let the user do the List.reverse themselves if
needed and make the cost more apparent.

    toSortedList (fromList identity [ 100, 3, 1, 4, 1, 5, 9, 200 ])
        --> [ 1, 1, 3, 4, 5, 9, 100, 200 ]

    List.reverse (toSortedList (fromList identity [ 100, 3, 1, 4, 1, 5, 9, 200 ]))
        --> [ 200, 100, 9, 5, 4, 3, 1, 1 ]

Anyways, let's continue with the rest of the docs!

@docs empty, singleton, fromList
@docs toList, toSortedList, fold
@docs insert, enqueue, filter, dequeue, dequeueMany, largest, head, tail, take, drop
@docs all, any, isEmpty, length

-}

import PriorityQueue exposing (PriorityQueue)



-- The schtick of this module is to be exactly like MinPriorityQueue, just replace `toPriority` with `toPriority >> negate` everywhere.
-- Also, the better name for `head` is `largest` here, not `smallest`.


{-| A priority queue giving the highest priority to largest Ints given by your
`(a -> Int)` function.

    MaxPriorityQueue.fromList .age
        [ { name = "Martin", age = 31 }
        , { name = "Xavier", age = 13 }
        , { name = "Joanne", age = 54 }
        ]
        |> MaxPriorityQueue.largest
        --> { name = "Joanne", age = 54 }

Note that MaxPriorityQueue is not `(==)`-safe.

-}
type MaxPriorityQueue a
    = MaxQ (PriorityQueue a)


{-| Create an empty MaxPriorityQueue.
-}
empty : MaxPriorityQueue a
empty =
    MaxQ PriorityQueue.empty


{-| Create a MaxPriorityQueue with a single element.

    singleton identity 5
        |> toList
        --> [ 5 ]

-}
singleton : (a -> Int) -> a -> MaxPriorityQueue a
singleton toPriority element =
    MaxQ <| PriorityQueue.singleton (toPriority >> negate) element


{-| Create a MaxPriorityQueue from a list of elements.

    fromList identity [ 3, 1, 4, 1, 5, 9 ]
        |> toSortedList
        --> [ 1, 1, 3, 4, 5, 9 ]

-}
fromList : (a -> Int) -> List a -> MaxPriorityQueue a
fromList toPriority list =
    MaxQ <| PriorityQueue.fromList (toPriority >> negate) list


{-| Convert a MaxPriorityQueue to a list.

The order of items in the resulting list is unspecified.
If you need a sorted list, use `toSortedList`.

    toList (fromList identity [ 100, 3, 1, 4, 1, 5, 9, 200 ])
        --> [ 200, 100, 4, 1, 1, 9, 5, 3]

-}
toList : MaxPriorityQueue a -> List a
toList (MaxQ pq) =
    PriorityQueue.toList pq


{-| Convert a MaxPriorityQueue to a sorted list.

The order of items in the resulting list is lowest-priority-first, thus may seem
reversed from what you want. See note at the top.

    toSortedList (fromList identity [ 100, 3, 1, 4, 1, 5, 9, 200 ])
        --> [ 1, 1, 3, 4, 5, 9, 100, 200 ]

-}
toSortedList : MaxPriorityQueue a -> List a
toSortedList (MaxQ pq) =
    PriorityQueue.toSortedList pq


{-| Fold over the elements in the MaxPriorityQueue, highest priority first.

    fromList identity [ 3, 1, 4 ]
        |> fold (\x acc -> x :: acc) []
        --> [ 1, 3, 4 ]

    fromList identity [ 3, 1, 4 ]
        |> fold (+) 0
        --> 8

    fromList Tuple.first [ (10, "World"), (1, "Hello"), (5, "Elm") ]
        |> fold (\(_, word) acc -> acc ++ " " ++ word) ""
        --> " World Elm Hello"

-}
fold : (a -> b -> b) -> b -> MaxPriorityQueue a -> b
fold f acc (MaxQ pq) =
    PriorityQueue.fold f acc pq


{-| Insert an element into a MaxPriorityQueue. O(log n).

    empty
        |> insert identity 3
        |> insert identity 4
        |> insert identity 1
        |> largest
        --> Just 4

-}
insert : (a -> Int) -> a -> MaxPriorityQueue a -> MaxPriorityQueue a
insert toPriority element (MaxQ pq) =
    MaxQ (PriorityQueue.insert (toPriority >> negate) element pq)


{-| Insert an element into a MaxPriorityQueue. O(log n).

This is an alias for `insert`.

    empty
        |> enqueue identity 3
        |> enqueue identity 4
        |> enqueue identity 1
        |> largest
        --> Just 4

-}
enqueue : (a -> Int) -> a -> MaxPriorityQueue a -> MaxPriorityQueue a
enqueue toPriority element mpq =
    insert toPriority element mpq


{-| Check if a MaxPriorityQueue is empty.

    isEmpty empty
        --> True

    isEmpty (singleton identity 1)
        --> False

-}
isEmpty : MaxPriorityQueue a -> Bool
isEmpty (MaxQ pq) =
    PriorityQueue.isEmpty pq


{-| Remove and return the element with the highest priority from the MaxPriorityQueue,
along with the updated queue. Returns Nothing if the queue is empty. O(log n).

    dequeue (fromList identity [ 3, 4, 1 ])
        --> Just ( 4, fromList identity [ 3, 1 ] )

    dequeue empty
        --> Nothing

-}
dequeue : MaxPriorityQueue a -> Maybe ( a, MaxPriorityQueue a )
dequeue (MaxQ pq) =
    PriorityQueue.dequeue pq
        |> Maybe.map (Tuple.mapSecond MaxQ)


{-| Retrieve the N items with highest priority, alongside the queue without them.

The order of items in the resulting list is lowest-priority-first, thus may seem
reversed from what you want. See note at the top.

    fromList identity [ 3, 1, 5, 2, 4 ]
        |> dequeueMany 3
        --> ( [ 3, 4, 5 ], fromList identity [ 1, 2 ] )

If you take more items than are in the queue, you will get all the items in the
queue.

    fromList identity [ 3, 1, 2 ]
        |> dequeueMany 5
        --> ( [ 1, 2, 3 ], empty )

-}
dequeueMany : Int -> MaxPriorityQueue a -> ( List a, MaxPriorityQueue a )
dequeueMany n (MaxQ pq) =
    PriorityQueue.dequeueMany n pq
        |> Tuple.mapSecond MaxQ


{-| Keep only the elements that satisfy the predicate.

    fromList identity [ 1, 2, 3, 4, 5 ]
        |> filter (\x -> modBy 2 x == 0)
        |> toSortedList
        --> [ 2, 4 ]

-}
filter : (a -> Bool) -> MaxPriorityQueue a -> MaxPriorityQueue a
filter predicate (MaxQ pq) =
    MaxQ <| PriorityQueue.filter predicate pq


{-| Retrieve the N items with highest priority. O(log n).

The order of items in the resulting list is lowest-priority-first, thus may seem
reversed from what you want. See note at the top.

    fromList identity [ 3, 1, 5, 2, 4 ]
        |> take 3
        --> [ 3, 4, 5 ]

If you take more items than are in the queue, you will get all the items in the
queue.

    take 1000 (singleton identity 1)
        --> [ 1 ]

-}
take : Int -> MaxPriorityQueue a -> List a
take n (MaxQ pq) =
    PriorityQueue.take n pq


{-| Drop the N items with highest priority from the queue. O(log n).

    fromList identity [ 3, 1, 5, 2, 4 ]
        |> drop 3
        |> toSortedList
        --> [ 1, 2 ]

If you drop more items than are in the queue, you will get an empty queue.

    drop 1000 (singleton identity 1)
        --> empty

-}
drop : Int -> MaxPriorityQueue a -> MaxPriorityQueue a
drop n (MaxQ pq) =
    MaxQ <| PriorityQueue.drop n pq


{-| Get the item with the highest priority without removing it from the queue.
Returns Nothing if the queue is empty. O(1).

    head (fromList identity [ 3, 4, 1 ])
        --> Just 4

    head empty
        --> Nothing

-}
head : MaxPriorityQueue a -> Maybe a
head (MaxQ pq) =
    PriorityQueue.head pq


{-| Get a new queue with the highest priority item removed.
Returns Nothing if the queue is empty. O(log n).

    tail (fromList identity [ 3, 4, 1 ])
        |> Maybe.map toSortedList
        --> Just [ 1, 3 ]

    tail empty
        --> Nothing

-}
tail : MaxPriorityQueue a -> Maybe (MaxPriorityQueue a)
tail (MaxQ pq) =
    PriorityQueue.tail pq
        |> Maybe.map MaxQ


{-| Get the item with the highest priority without removing it from the queue.
Returns Nothing if the queue is empty. O(1).

This is an alias for `head`.

    largest (fromList identity [ 3, 4, 1 ])
        --> Just 4

    largest empty
        --> Nothing

-}
largest : MaxPriorityQueue a -> Maybe a
largest mpq =
    head mpq


{-| Determine if all elements satisfy the predicate.

    fromList identity [ 1, 2, 3 ]
        |> all (\x -> x > 10)
        == False

    fromList identity [ 9, 11 ]
        |> all (\x -> x > 10)
        == False

    fromList identity [ 15, 16, 17 ]
        |> all (\x -> x > 10)
        == True

    all (\_ -> True) empty --> True

    all (\_ -> True) (singleton identity 1) --> True

    all (\_ -> False) empty --> True

    all (\_ -> False) (singleton identity 1) --> False

-}
all : (a -> Bool) -> MaxPriorityQueue a -> Bool
all predicate (MaxQ pq) =
    PriorityQueue.all predicate pq


{-| Determine if any elements satisfy the predicate.

    fromList identity [ 1, 2, 3 ]
        |> any (\x -> x > 10)
        == False

    fromList identity [ 9, 11 ]
        |> any (\x -> x > 10)
        == True

    fromList identity [ 15, 16, 17 ]
        |> any (\x -> x > 10)
        == True

    any (\_ -> True) empty --> False

    any (\_ -> True) (singleton identity 1) --> True

    any (\_ -> False) empty --> False

    any (\_ -> False) (singleton identity 1) --> False

-}
any : (a -> Bool) -> MaxPriorityQueue a -> Bool
any predicate (MaxQ pq) =
    PriorityQueue.any predicate pq


{-| Get the number of elements in the queue. O(1).

    length (fromList identity [ 1, 2, 3 ])
        --> 3

    length empty
        --> 0

-}
length : MaxPriorityQueue a -> Int
length (MaxQ pq) =
    PriorityQueue.length pq
