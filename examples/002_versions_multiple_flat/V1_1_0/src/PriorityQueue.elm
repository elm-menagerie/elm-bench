module PriorityQueue exposing
    ( PriorityQueue
    , empty, singleton, fromList
    , toList, toSortedList, fold
    , insert, filter, dequeue, dequeueMany, head, tail, take, drop
    , all, any, isEmpty, length
    )

{-|

@docs PriorityQueue
@docs empty, singleton, fromList
@docs toList, toSortedList, fold
@docs insert, filter, dequeue, dequeueMany, head, tail, take, drop
@docs all, any, isEmpty, length

-}


type alias Rank =
    Int


type alias Length =
    Int


type alias Priority =
    Int


{-| heap-ordered binary tree with the _leftist property_

The leftist property is that the _rank_ of any left child is at least as large as that of its right sibling. The rank of a node is defined as the length of its _right spine_, i.e. the right-most path of the node in question to an empty node.

-}
type PriorityQueue a
    = Empty
    | Node Rank Length ( a, Priority ) (PriorityQueue a) (PriorityQueue a)


empty : PriorityQueue a
empty =
    Empty


singleton : (a -> Priority) -> a -> PriorityQueue a
singleton toPriority x =
    Node 1 1 ( x, toPriority x ) Empty Empty


fromList : (a -> Priority) -> List a -> PriorityQueue a
fromList toPriority xs =
    xs
        |> List.foldl (insert toPriority) empty


filter : (a -> Bool) -> PriorityQueue a -> PriorityQueue a
filter pred q =
    case q of
        Empty ->
            q

        Node r _ ( element, p ) a b ->
            if pred element then
                let
                    filteredA : PriorityQueue a
                    filteredA =
                        filter pred a

                    filteredB : PriorityQueue a
                    filteredB =
                        filter pred b

                    lengthA : Int
                    lengthA =
                        length filteredA

                    lengthB : Int
                    lengthB =
                        length filteredB
                in
                Node r (1 + lengthA + lengthB) ( element, p ) filteredA filteredB

            else
                merge (filter pred a) (filter pred b)


dequeue : PriorityQueue a -> Maybe ( a, PriorityQueue a )
dequeue q =
    case q of
        Empty ->
            Nothing

        Node _ _ ( element, _ ) a b ->
            Just ( element, merge a b )


dequeueMany : Int -> PriorityQueue a -> ( List a, PriorityQueue a )
dequeueMany n q =
    let
        go : Int -> PriorityQueue a -> List a -> ( List a, PriorityQueue a )
        go nn qq acc =
            if nn <= 0 then
                ( acc, qq )

            else
                case dequeue qq of
                    Nothing ->
                        ( acc, qq )

                    Just ( x, q__ ) ->
                        go (nn - 1) q__ (x :: acc)
    in
    go n q []


toList : PriorityQueue a -> List a
toList q =
    case q of
        Empty ->
            []

        Node _ _ ( element, _ ) a b ->
            element :: (toList a ++ toList b)


toSortedList : PriorityQueue a -> List a
toSortedList q =
    let
        go : PriorityQueue a -> List a -> List a
        go qq acc =
            case qq of
                Empty ->
                    acc

                Node _ _ ( element, _ ) a b ->
                    go (merge a b) (element :: acc)
    in
    go q []


insert : (a -> Priority) -> a -> PriorityQueue a -> PriorityQueue a
insert toPriority x q =
    let
        xq : PriorityQueue a
        xq =
            singleton toPriority x
    in
    merge xq q


isEmpty : PriorityQueue a -> Bool
isEmpty q =
    case q of
        Empty ->
            True

        Node _ _ _ _ _ ->
            False


head : PriorityQueue a -> Maybe a
head q =
    case q of
        Empty ->
            Nothing

        Node _ _ ( element, _ ) _ _ ->
            Just element


tail : PriorityQueue a -> Maybe (PriorityQueue a)
tail q =
    case q of
        Empty ->
            Nothing

        Node _ _ _ a b ->
            Just <| merge a b


take : Int -> PriorityQueue a -> List a
take n q =
    let
        go : Int -> PriorityQueue a -> List a -> List a
        go n_ q_ acc =
            if n_ <= 0 then
                acc

            else
                case dequeue q_ of
                    Nothing ->
                        acc

                    Just ( x, q__ ) ->
                        go (n_ - 1) q__ (x :: acc)
    in
    go n q []


drop : Int -> PriorityQueue a -> PriorityQueue a
drop n q =
    if n <= 0 then
        q

    else
        case q of
            Empty ->
                q

            Node _ _ _ a b ->
                drop (n - 1) (merge a b)


all : (a -> Bool) -> PriorityQueue a -> Bool
all pred q =
    let
        go : PriorityQueue a -> Bool
        go queue =
            case queue of
                Empty ->
                    True

                Node _ _ ( element, _ ) a b ->
                    if pred element then
                        go (merge a b)

                    else
                        False
    in
    go q


any : (a -> Bool) -> PriorityQueue a -> Bool
any pred q =
    let
        go : PriorityQueue a -> Bool
        go queue =
            case queue of
                Empty ->
                    False

                Node _ _ ( element, _ ) a b ->
                    if pred element then
                        True

                    else
                        go (merge a b)
    in
    go q


length : PriorityQueue a -> Int
length q =
    case q of
        Empty ->
            0

        Node _ l _ _ _ ->
            l


fold : (a -> b -> b) -> b -> PriorityQueue a -> b
fold f acc q =
    case q of
        Empty ->
            acc

        Node _ _ ( element, _ ) a b ->
            fold f (f element acc) (merge a b)



-- HELPERS


{-| Merge two trees while maintaining the _leftist property_
-}
merge : PriorityQueue a -> PriorityQueue a -> PriorityQueue a
merge left right =
    case ( left, right ) of
        ( Empty, _ ) ->
            right

        ( _, Empty ) ->
            left

        ( Node _ _ ( x, xp ) a b, Node _ _ ( y, yp ) u v ) ->
            if xp <= yp then
                make ( x, xp ) a (merge b right)

            else
                make ( y, yp ) u (merge left v)


{-| Create a non empty tree from an element and two sub-trees, keeping the _leftist property_ intact.
-}
make : ( a, Priority ) -> PriorityQueue a -> PriorityQueue a -> PriorityQueue a
make x a b =
    let
        len : Int
        len =
            1 + length a + length b
    in
    if rank a >= rank b then
        Node (1 + rank b) len x a b

    else
        Node (1 + rank a) len x b a


rank : PriorityQueue a -> Rank
rank q =
    case q of
        Empty ->
            0

        Node r _ _ _ _ ->
            r
