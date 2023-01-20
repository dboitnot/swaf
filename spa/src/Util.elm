module Util exposing (boolToMaybe, flattenMaybeList, formatFileSize, httpErrorToString, maybeEmptyString)

import Http
import Round


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


formatFileSize : Int -> String
formatFileSize bytes =
    let
        floatBytes : Float
        floatBytes =
            toFloat bytes
    in
    [ { n = 1024.0, suffix = "K" }
    , { n = 1048576.0, suffix = "M" }
    , { n = 1073741824.0, suffix = "G" }
    , { n = 1099511627776.0, suffix = "T" }
    , { n = 1125899906842624.0, suffix = "P" }
    ]
        |> List.filter (\i -> i.n < floatBytes)
        |> List.reverse
        |> List.head
        |> Maybe.map (\i -> { i | n = floatBytes / i.n })
        |> Maybe.map (\i -> Round.round 1 i.n ++ i.suffix)
        |> Maybe.withDefault (String.fromInt bytes)


httpErrorToString : Http.Error -> String
httpErrorToString error =
    case error of
        Http.BadUrl s ->
            "Bad URL: " ++ s

        Http.Timeout ->
            "Timeout"

        Http.NetworkError ->
            "Network Error"

        Http.BadStatus i ->
            "Server returned status " ++ String.fromInt i

        Http.BadBody s ->
            "Error parsing server response: " ++ s
