module Remove exposing (remove)


remove : a -> List a -> List a
remove x xs =
    removeHelp xs x xs []


removeHelp : List a -> a -> List a -> List a -> List a
removeHelp list x xs previousElements =
    case xs of
        [] ->
            list

        y :: ys ->
            if x == y then
                reverseAppend previousElements ys

            else
                removeHelp list x ys (y :: previousElements)


reverseAppend : List a -> List a -> List a
reverseAppend list1 list2 =
    List.foldl (::) list2 list1
