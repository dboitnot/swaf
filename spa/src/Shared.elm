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


type alias Flags =
    Json.Value


type alias Model =
    { user : Maybe User }


type alias User =
    { info : UserInfo }


type Msg
    = SignIn User
    | SignOut


init : Request -> Flags -> ( Model, Cmd Msg )
init _ _ =
    ( { user = Nothing }, Cmd.none )


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
