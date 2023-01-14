module Pages.Home_ exposing (Model, Msg, page)

import Html as H
import Http
import Model exposing (User, userDecoder)
import Page
import RemoteData exposing (WebData)
import Request exposing (Request)
import Shared
import View exposing (View)
import W.Styles


type Msg
    = UserResponse (WebData User)


type alias Model =
    { clickCount : Int
    , user : WebData User
    }


page : Shared.Model -> Request -> Page.With Model Msg
page _ _ =
    Page.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


init : ( Model, Cmd Msg )
init =
    ( { clickCount = 0, user = RemoteData.Loading }
    , getUser
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UserResponse user ->
            ( { model | user = user }, Cmd.none )


view : Model -> View Msg
view model =
    { title = "HI there"
    , body =
        [ H.div []
            [ W.Styles.globalStyles
            , W.Styles.baseTheme

            -- , W.Button.view [] { label = [ H.text ("Hi " ++ String.fromInt model.clickCount) ], onClick = Clicked }
            , H.text (textToDisplay model)
            ]
        ]
    }


textToDisplay : Model -> String
textToDisplay model =
    case model.user of
        RemoteData.NotAsked ->
            "Initializing..."

        RemoteData.Loading ->
            "Loading..."

        RemoteData.Failure (Http.BadStatus 401) ->
            "Got a 401"

        RemoteData.Failure e ->
            "Error: " ++ Debug.toString e

        RemoteData.Success _ ->
            "Got a user"


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


getUser : Cmd Msg
getUser =
    Http.get
        { url = "http://localhost:8000/user/current"
        , expect = userDecoder |> Http.expectJson (RemoteData.fromResult >> UserResponse)
        }
