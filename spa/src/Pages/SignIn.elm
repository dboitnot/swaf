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
page model _ =
    Page.advanced
        { init = init model
        , update = update model
        , view = view
        , subscriptions = subscriptions
        }



-- INIT


type alias Model =
    { getUserRequest : WebData UserInfo
    , signInRequest : WebData UserInfo
    }


init : Shared.Model -> ( Model, Effect Msg )
init sharedModel =
    ( { getUserRequest = RemoteData.NotAsked
      , signInRequest = RemoteData.NotAsked
      }
    , Effect.fromCmd (sendGetUser sharedModel)
    )



-- UPDATE


type Msg
    = GetUserResponse (WebData UserInfo)
    | ClickedSignIn
    | SignInResponse (WebData UserInfo)


update : Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update sharedModel msg model =
    case msg of
        GetUserResponse (RemoteData.Success userInfo) ->
            ( model, Effect.fromShared (Shared.SignIn { info = userInfo }) )

        GetUserResponse r ->
            ( { model | getUserRequest = r }, Effect.none )

        ClickedSignIn ->
            ( model, Effect.fromCmd (sendSignIn sharedModel) )

        SignInResponse (RemoteData.Success userInfo) ->
            ( model, Effect.fromShared (Shared.SignIn { info = userInfo }) )

        SignInResponse r ->
            ( { model | signInRequest = r }, Effect.none )


sendGetUser : Shared.Model -> Cmd Msg
sendGetUser sharedModel =
    Http.get
        { url = sharedModel.baseUrl ++ "/api/user/current"
        , expect = userInfoDecoder |> Http.expectJson (RemoteData.fromResult >> GetUserResponse)
        }


sendSignIn : Shared.Model -> Cmd Msg
sendSignIn sharedModel =
    Http.post
        { url = sharedModel.baseUrl ++ "/api/login"
        , body = Http.emptyBody
        , expect = userInfoDecoder |> Http.expectJson (RemoteData.fromResult >> SignInResponse)
        }



-- VIEW


view : Model -> View Msg
view _ =
    -- TODO: Add a spinner for the getUserRequest
    -- TODO: Disable sign-in button after it's been clicked
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
