module Shared exposing
    ( Flags
    , Model
    , Msg(..)
    , User
    , init
    , subscriptions
    , update
    )

import Gen.Route
import Json.Decode as Json
import Model exposing (UserInfo)
import Request exposing (Request)
import Url exposing (Url)


type alias Flags =
    Json.Value


type alias Model =
    { user : Maybe User
    , baseUrl : String
    }


type alias User =
    { info : UserInfo }


type Msg
    = SignIn User
    | SignOut


init : Request -> Flags -> ( Model, Cmd Msg )
init req _ =
    let
        reqUrl : Url
        reqUrl =
            req.url
    in
    ( { user = Nothing, baseUrl = Url.toString { reqUrl | path = "" } }, Cmd.none )


update : Request -> Msg -> Model -> ( Model, Cmd Msg )
update req msg model =
    case msg of
        SignIn user ->
            ( { model | user = Just user }
            , Request.pushRoute Gen.Route.Home_ req
            )

        SignOut ->
            -- TODO: Send sign-out to API
            ( model, Cmd.none )


subscriptions : Request -> Model -> Sub Msg
subscriptions _ _ =
    Sub.none