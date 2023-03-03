module Api.Response exposing (Response(..), fromResult, mapUpdate, update)

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
