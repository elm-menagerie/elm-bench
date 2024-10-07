module MinPriorityQueue exposing
    ( MinPriorityQueue
    , empty, singleton, fromList
    , toList, toSortedList, fold
    , insert, enqueue, filter, dequeue, dequeueMany, smallest, head, tail, take, drop
    , all, any, isEmpty, length
    )

{-| The `(a -> Int)` function given to `singleton`, `insert`, `enqueue` and `fromList`
is how you teach the queue to get the priority of an item. `MinPriorityQueue` will
prioritize items with smaller Ints.

@docs MinPriorityQueue

**Note:** Some functions in this module return lists of values in perhaps a slightly
unexpected reversed order (`toSortedList`, `dequeueMany`, `take`). This is done
in name of efficiency: there's no trick to efficiently return it in the more
expected reverse order, so we let the user do the List.reverse themselves if
needed and make the cost more apparent.

    toSortedList (fromList identity [ 100, 3, 1, 4, 1, 5, 9, 200 ])
        --> [ 200, 100, 9, 5, 4, 3, 1, 1 ]

    List.reverse (toSortedList (fromList identity [ 100, 3, 1, 4, 1, 5, 9, 200 ]))
        --> [ 1, 1, 3, 4, 5, 9, 100, 200 ]

Anyways, let's continue with the rest of the docs!

@docs empty, singleton, fromList
@docs toList, toSortedList, fold
@docs insert, enqueue, filter, dequeue, dequeueMany, smallest, head, tail, take, drop
@docs all, any, isEmpty, length

-}

import PriorityQueue exposing (PriorityQueue)


{-| A priority queue giving the highest priority to smallest Ints given by your
`(a -> Int)` function.

    MinPriorityQueue.fromList .age
        [ { name = "Martin", age = 31 }
        , { name = "Xavier", age = 13 }
        , { name = "Joanne", age = 54 }
        ]
        |> MinPriorityQueue.smallest
        --> { name = "Xavier", age = 13 }

Note that MinPriorityQueue is not `(==)`-safe.

-}
type MinPriorityQueue a
    = MinQ (PriorityQueue a)


{-| Create an empty MinPriorityQueue.
-}
empty : MinPriorityQueue a
empty =
    MinQ PriorityQueue.empty


{-| Create a MinPriorityQueue with a single element.

    singleton identity 5
        |> toList
        --> [ 5 ]

-}
singleton : (a -> Int) -> a -> MinPriorityQueue a
singleton toPriority element =
    MinQ <| PriorityQueue.singleton toPriority element


{-| Create a MinPriorityQueue from a list of elements.

    fromList identity [ 3, 1, 4, 1, 5, 9 ]
        |> toSortedList
        --> [ 1, 1, 3, 4, 5, 9 ]

-}
fromList : (a -> Int) -> List a -> MinPriorityQueue a
fromList toPriority list =
    MinQ <| PriorityQueue.fromList toPriority list


{-| Convert a MinPriorityQueue to a list.

The order of items in the resulting list is unspecified.
If you need a sorted list, use `toSortedList`.

    toList (fromList identity [ 100, 3, 1, 4, 1, 5, 9, 200 ])
        --> [ 1, 1, 3, 100, 4, 5, 9, 200 ]

-}
toList : MinPriorityQueue a -> List a
toList (MinQ pq) =
    PriorityQueue.toList pq


{-| Convert a MinPriorityQueue to a sorted list.

The order of items in the resulting list is lowest-priority-first, thus may seem
reversed from what you want. See note at the top.

    toSortedList (fromList identity [ 100, 3, 1, 4, 1, 5, 9, 200 ])
        --> [ 200, 100, 9, 5, 4, 3, 1, 1 ]

-}
toSortedList : MinPriorityQueue a -> List a
toSortedList (MinQ pq) =
    PriorityQueue.toSortedList pq


{-| Fold over the elements in the MinPriorityQueue, highest priority first.

    fromList identity [ 3, 1, 4 ]
        |> fold (\x acc -> x :: acc) []
        --> [ 4, 3, 1 ]

    fromList identity [ 3, 1, 4 ]
        |> fold (+) 0
        --> 8

    fromList Tuple.first [ (10, "World"), (1, "Hello"), (5, "Elm") ]
        |> fold (\(_, word) acc -> acc ++ " " ++ word) ""
        --> " Hello Elm World"

-}
fold : (a -> b -> b) -> b -> MinPriorityQueue a -> b
fold f acc (MinQ pq) =
    PriorityQueue.fold f acc pq


{-| Insert an element into a MinPriorityQueue. O(log n).

    empty
        |> insert identity 3
        |> insert identity 1
        |> insert identity 4
        |> smallest
        --> Just 1

-}
insert : (a -> Int) -> a -> MinPriorityQueue a -> MinPriorityQueue a
insert toPriority element (MinQ pq) =
    MinQ (PriorityQueue.insert toPriority element pq)


{-| Insert an element into a MinPriorityQueue. O(log n).

This is an alias for `insert`.

    empty
        |> enqueue identity 3
        |> enqueue identity 1
        |> enqueue identity 4
        |> smallest
        --> Just 1

-}
enqueue : (a -> Int) -> a -> MinPriorityQueue a -> MinPriorityQueue a
enqueue toPriority element mpq =
    insert toPriority element mpq


{-| Check if a MinPriorityQueue is empty.

    isEmpty empty
        --> True

    isEmpty (singleton identity 1)
        --> False

-}
isEmpty : MinPriorityQueue a -> Bool
isEmpty (MinQ pq) =
    PriorityQueue.isEmpty pq


{-| Remove and return the element with the highest priority from the MinPriorityQueue,
along with the updated queue. Returns Nothing if the queue is empty. O(log n).

    dequeue (fromList identity [ 3, 1, 4 ])
        --> Just ( 1, fromList identity [ 3, 4 ] )

    dequeue empty
        --> Nothing

-}
dequeue : MinPriorityQueue a -> Maybe ( a, MinPriorityQueue a )
dequeue (MinQ pq) =
    PriorityQueue.dequeue pq
        |> Maybe.map (Tuple.mapSecond MinQ)


{-| Retrieve the N items with highest priority, alongside the queue without them.

The order of items in the resulting list is lowest-priority-first, thus may seem
reversed from what you want. See note at the top.

    fromList identity [ 3, 1, 5, 2, 4 ]
        |> dequeueMany 3
        --> ( [ 3, 2, 1 ], fromList identity [ 5, 4 ] )

If you take more items than are in the queue, you will get all the items in the
queue.

    fromList identity [ 3, 1, 2 ]
        |> dequeueMany 5
        --> ( [ 3, 2, 1 ], empty )

-}
dequeueMany : Int -> MinPriorityQueue a -> ( List a, MinPriorityQueue a )
dequeueMany n (MinQ pq) =
    PriorityQueue.dequeueMany n pq
        |> Tuple.mapSecond MinQ


{-| Keep only the elements that satisfy the predicate.

    fromList identity [ 1, 2, 3, 4, 5 ]
        |> filter (\x -> modBy 2 x == 0)
        |> toSortedList
        --> [ 4, 2 ]

-}
filter : (a -> Bool) -> MinPriorityQueue a -> MinPriorityQueue a
filter predicate (MinQ pq) =
    MinQ <| PriorityQueue.filter predicate pq


{-| Retrieve the N items with highest priority. O(log n).

The order of items in the resulting list is lowest-priority-first, thus may seem
reversed from what you want. See note at the top.

    fromList identity [ 3, 1, 5, 2, 4 ]
        |> take 3
        --> [ 3, 2, 1 ]

If you take more items than are in the queue, you will get all the items in the
queue.

    take 1000 (singleton identity 1)
        --> [ 1 ]

-}
take : Int -> MinPriorityQueue a -> List a
take n (MinQ pq) =
    PriorityQueue.take n pq


{-| Drop the N items with highest priority from the queue. O(log n).

    fromList identity [ 3, 1, 5, 2, 4 ]
        |> drop 3
        |> toSortedList
        --> [ 5, 4 ]

If you drop more items than are in the queue, you will get an empty queue.

    drop 1000 (singleton identity 1)
        --> empty

-}
drop : Int -> MinPriorityQueue a -> MinPriorityQueue a
drop n (MinQ pq) =
    MinQ <| PriorityQueue.drop n pq


{-| Get the item with the highest priority without removing it from the queue.
Returns Nothing if the queue is empty. O(1).

    head (fromList identity [ 3, 1, 4 ])
        --> Just 1

    head empty
        --> Nothing

-}
head : MinPriorityQueue a -> Maybe a
head (MinQ pq) =
    PriorityQueue.head pq


{-| Get a new queue with the highest priority item removed.
Returns Nothing if the queue is empty. O(log n).

    tail (fromList identity [ 3, 1, 4 ])
        |> Maybe.map toSortedList
        --> Just [ 4, 3 ]

    tail empty
        --> Nothing

-}
tail : MinPriorityQueue a -> Maybe (MinPriorityQueue a)
tail (MinQ pq) =
    PriorityQueue.tail pq
        |> Maybe.map MinQ


{-| Get the item with the highest priority without removing it from the queue.
Returns Nothing if the queue is empty. O(1).

This is an alias for `head`.

    smallest (fromList identity [ 3, 1, 4 ])
        --> Just 1

    smallest empty
        --> Nothing

-}
smallest : MinPriorityQueue a -> Maybe a
smallest mpq =
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
all : (a -> Bool) -> MinPriorityQueue a -> Bool
all predicate (MinQ pq) =
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
any : (a -> Bool) -> MinPriorityQueue a -> Bool
any predicate (MinQ pq) =
    PriorityQueue.any predicate pq


{-| Get the number of elements in the queue. O(1).

    length (fromList identity [ 1, 2, 3 ])
        --> 3

    length empty
        --> 0

-}
length : MinPriorityQueue a -> Int
length (MinQ pq) =
    PriorityQueue.length pq
