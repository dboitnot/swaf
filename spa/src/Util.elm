module Util exposing
    ( authorizedUpdate
    , boolToMaybe
    , flattenMaybeList
    , formatFileSize
    , httpErrorToString
    , maybeEmptyString
    , maybeIs
    , pathJoin
    , sortBy
    , thenSortBy
    )

import Gen.Route
import Http
import RemoteData exposing (WebData)
import Request exposing (Request)
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


maybeIs : Maybe a -> Bool
maybeIs m =
    case m of
        Just _ ->
            True

        Nothing ->
            False


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


authorizedUpdate : Request -> mod -> WebData d -> (() -> ( mod, Cmd msg )) -> ( mod, Cmd msg )
authorizedUpdate req mod res fnIfAuthorized =
    case res of
        RemoteData.Failure (Http.BadStatus 401) ->
            ( mod, Request.pushRoute Gen.Route.SignIn req )

        _ ->
            fnIfAuthorized ()


sortBy : (o -> comparable) -> (o -> o -> Order)
sortBy fn =
    \a b -> compare (fn a) (fn b)


thenSortBy : (o -> comparable) -> (o -> o -> Order) -> (o -> o -> Order)
thenSortBy next first =
    \a b ->
        case first a b of
            EQ ->
                compare (next a) (next b)

            e ->
                e


pathJoin : String -> String -> String
pathJoin parent child =
    if String.isEmpty parent then
        child

    else if String.endsWith "/" parent then
        parent ++ child

    else
        parent ++ "/" ++ child
