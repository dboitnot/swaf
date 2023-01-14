module Pages.Home_ exposing (Model, Msg, page)

import Html as H
import Http
import Page
import RemoteData exposing (WebData)
import Request exposing (Request)
import Shared exposing (User)
import View exposing (View)
import W.Styles


type Msg
    = NoOp


type alias Model =
    { clickCount : Int
    , user : User
    }


page : Shared.Model -> Request -> Page.With Model Msg
page _ _ =
    Page.protected.element
        (\user ->
            { init = init user
            , update = update
            , view = view
            , subscriptions = subscriptions
            }
        )


init : User -> ( Model, Cmd Msg )
init user =
    ( { clickCount = 0, user = user }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update _ model =
    ( model, Cmd.none )


view : Model -> View Msg
view model =
    { title = "HI there"
    , body =
        [ H.div []
            [ W.Styles.globalStyles
            , W.Styles.baseTheme
            , H.text (textToDisplay model)
            ]
        ]
    }


textToDisplay : Model -> String
textToDisplay model =
    case model.user.info.fullName of
        Just name ->
            "Hi there " ++ name

        Nothing ->
            model.user.info.loginName


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
