module Remove exposing (removeNew, removeOld)


removeOld : a -> List a -> List a
removeOld x xs =
    case xs of
        [] ->
            []

        y :: ys ->
            if x == y then
                ys

            else
                y :: removeOld x ys


removeNew : a -> List a -> List a
removeNew x xs =
    removeNewHelp xs x xs []


removeNewHelp : List a -> a -> List a -> List a -> List a
removeNewHelp list x xs previousElements =
    case xs of
        [] ->
            list

        y :: ys ->
            if x == y then
                reverseAppend previousElements ys

            else
                removeNewHelp list x ys (y :: previousElements)


reverseAppend : List a -> List a -> List a
reverseAppend list1 list2 =
    List.foldl (::) list2 list1
