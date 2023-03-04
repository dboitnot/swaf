module Api.Response exposing
    ( Response(..)
    , andMaybeMap
    , andMaybeThen
    , fromResult
    , mapUpdate
    , onRemoteError
    , or
    , orMaybe
    , toResult
    , update
    )

import Gen.Route
import Http exposing (Error)
import Into as I
import RemoteData exposing (WebData)
import Request exposing (Request)


type Response a
    = Unauthorized
    | Authorized (WebData a)



-- Unauthorized (Request.pushRoute Gen.Route.SignIn req)


fromResult : Result Error a -> Response a
fromResult res =
    case res of
        Err (Http.BadStatus 401) ->
            Unauthorized

        _ ->
            res |> RemoteData.fromResult |> Authorized


toResult : Request -> model -> Response a -> Result ( model, Cmd msg ) (WebData a)
toResult req model res =
    case res of
        Unauthorized ->
            Err ( model, Request.pushRoute Gen.Route.SignIn req )

        Authorized wd ->
            Ok wd


map : (a -> b) -> Response a -> Response b
map fn res =
    case res of
        Unauthorized ->
            Unauthorized

        Authorized wd ->
            wd |> RemoteData.map fn |> Authorized


update : Request -> Response a -> I.Zipper (WebData a) model -> ( model, Cmd msg )
update req res zip =
    case res of
        Unauthorized ->
            ( I.unzip zip, Request.pushRoute Gen.Route.SignIn req )

        Authorized wd ->
            ( zip |> I.set wd, Cmd.none )


mapUpdate : Request -> (a -> b) -> Response a -> I.Zipper (WebData b) model -> ( model, Cmd msg )
mapUpdate req fn res zip =
    update req (res |> map fn) zip



-- Semi-Related Utilities


onRemoteError :
    (Error -> model)
    -> Result ( model, Cmd msg ) (WebData a)
    -> Result ( model, Cmd msg ) (WebData a)
onRemoteError fn res =
    case res of
        Ok (RemoteData.Failure e) ->
            Err ( fn e, Cmd.none )

        _ ->
            res


andMaybeMap : (a -> b) -> Result e (Maybe a) -> Result e (Maybe b)
andMaybeMap fn res =
    case res of
        Ok m ->
            Ok (Maybe.map fn m)

        Err e ->
            Err e


andMaybeThen : (a -> Maybe b) -> Result e (Maybe a) -> Result e (Maybe b)
andMaybeThen fn res =
    case res of
        Ok m ->
            Ok (Maybe.andThen fn m)

        Err e ->
            Err e


orMaybe : a -> Result e (Maybe a) -> Result e a
orMaybe a res =
    case res of
        Ok m ->
            Ok (Maybe.withDefault a m)

        Err e ->
            Err e


or : Result a a -> a
or res =
    case res of
        Ok a ->
            a

        Err a ->
            a
