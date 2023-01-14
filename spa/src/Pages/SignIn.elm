module Pages.SignIn exposing (Model, Msg, page)

import Effect exposing (Effect)
import Gen.Params.SignIn exposing (Params)
import Html as H
import Http
import Model exposing (UserInfo, userInfoDecoder)
import Page
import RemoteData exposing (WebData)
import Request
import Shared
import View exposing (View)
import W.Button
import W.Styles


page : Shared.Model -> Request.With Params -> Page.With Model Msg
page _ _ =
    Page.advanced
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- INIT


type alias Model =
    { signInRequest : WebData UserInfo }


init : ( Model, Effect Msg )
init =
    ( { signInRequest = RemoteData.NotAsked }, Effect.none )



-- UPDATE


type Msg
    = ClickedSignIn
    | SignInResponse (WebData UserInfo)


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        ClickedSignIn ->
            ( model, Effect.fromCmd sendSignIn )

        SignInResponse (RemoteData.Success userInfo) ->
            ( model, Effect.fromShared (Shared.SignIn { info = userInfo }) )

        SignInResponse r ->
            ( { model | signInRequest = r }, Effect.none )


sendSignIn : Cmd Msg
sendSignIn =
    Http.post
        { url = "http://localhost:8001/api/login"
        , body = Http.emptyBody
        , expect = userInfoDecoder |> Http.expectJson (RemoteData.fromResult >> SignInResponse)
        }



-- VIEW


view : Model -> View Msg
view _ =
    { title = "Sign In"
    , body =
        [ H.div []
            [ W.Styles.globalStyles
            , W.Styles.baseTheme
            , W.Button.view [] { label = [ H.text "Sign In" ], onClick = ClickedSignIn }
            ]
        ]
    }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
