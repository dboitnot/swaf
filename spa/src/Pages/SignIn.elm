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
import Util exposing (maybeEmptyString)
import View exposing (View)
import W.Button
import W.Container
import W.InputText
import W.Loading
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
    , username : Maybe String
    , password : Maybe String
    }


init : Shared.Model -> ( Model, Effect Msg )
init sharedModel =
    ( { getUserRequest = RemoteData.NotAsked
      , signInRequest = RemoteData.NotAsked
      , username = Nothing
      , password = Nothing
      }
    , Effect.fromCmd (sendGetUser sharedModel)
    )



-- UPDATE


type Msg
    = GetUserResponse (WebData UserInfo)
    | SignInClicked
    | SignInResponse (WebData UserInfo)
    | UsernameChanged String
    | PasswordChanged String


update : Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update sharedModel msg model =
    case msg of
        GetUserResponse (RemoteData.Success userInfo) ->
            ( model, Effect.fromShared (Shared.SignIn { info = userInfo }) )

        GetUserResponse r ->
            ( { model | getUserRequest = r }, Effect.none )

        SignInClicked ->
            ( model, Effect.fromCmd (sendSignIn sharedModel model) )

        SignInResponse (RemoteData.Success userInfo) ->
            ( model, Effect.fromShared (Shared.SignIn { info = userInfo }) )

        SignInResponse r ->
            ( { model | password = Nothing, signInRequest = r }, Effect.none )

        UsernameChanged s ->
            ( { model | username = maybeEmptyString s }, Effect.none )

        PasswordChanged s ->
            ( { model | password = maybeEmptyString s }, Effect.none )


sendGetUser : Shared.Model -> Cmd Msg
sendGetUser sharedModel =
    Http.get
        { url = sharedModel.baseUrl ++ "/api/user/current"
        , expect = userInfoDecoder |> Http.expectJson (RemoteData.fromResult >> GetUserResponse)
        }


sendSignIn : Shared.Model -> Model -> Cmd Msg
sendSignIn sharedModel model =
    if signInDisabled model then
        Cmd.none

    else
        Http.post
            { url = sharedModel.baseUrl ++ "/api/login"
            , body =
                Http.multipartBody
                    [ Http.stringPart "login_name" (Maybe.withDefault "" model.username)
                    , Http.stringPart "password" (Maybe.withDefault "" model.password)
                    ]
            , expect = userInfoDecoder |> Http.expectJson (RemoteData.fromResult >> SignInResponse)
            }


signInDisabled : Model -> Bool
signInDisabled model =
    model.signInRequest == RemoteData.Loading



-- VIEW


view : Model -> View Msg
view model =
    -- TODO: Add a spinner for the getUserRequest
    -- TODO: Disable sign-in button after it's been clicked
    { title = "Sign In"
    , body =
        [ H.div []
            [ W.Styles.globalStyles
            , W.Styles.baseTheme
            , W.Container.view [ W.Container.vertical, W.Container.alignCenterX ]
                (signInView model)
            ]
        ]
    }


signInView : Model -> List (H.Html Msg)
signInView model =
    case model.getUserRequest of
        RemoteData.NotAsked ->
            signInSpinner

        RemoteData.Loading ->
            signInSpinner

        RemoteData.Failure _ ->
            signInInputs model

        RemoteData.Success _ ->
            signInInputs model


signInSpinner : List (H.Html Msg)
signInSpinner =
    [ W.Loading.circles [ W.Loading.size 60 ] ]


signInInputs : Model -> List (H.Html Msg)
signInInputs model =
    [ W.InputText.view [ W.InputText.placeholder "Username" ]
        { onInput = UsernameChanged, value = Maybe.withDefault "" model.username }
    , W.InputText.view [ W.InputText.placeholder "Password", W.InputText.password, W.InputText.onEnter SignInClicked ]
        { onInput = PasswordChanged, value = Maybe.withDefault "" model.password }
    , signInButton model
    ]


signInButton : Model -> H.Html Msg
signInButton model =
    W.Button.view [ W.Button.disabled (signInDisabled model) ]
        { label = [ H.text "Sign In" ], onClick = SignInClicked }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
