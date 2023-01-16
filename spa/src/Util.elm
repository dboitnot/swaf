module Util exposing (boolToMaybe, flattenMaybeList, maybeEmptyString)


flattenMaybeList : List (Maybe a) -> List a
flattenMaybeList lst =
    lst
        |> List.map (Maybe.map List.singleton)
        |> List.concatMap (Maybe.withDefault [])


maybeEmptyString : String -> Maybe String
maybeEmptyString s =
    if String.length s > 0 then
        Just s

    else
        Nothing


boolToMaybe : a -> Bool -> Maybe a
boolToMaybe trueValue b =
    if b then
        Just trueValue

    else
        Nothing
