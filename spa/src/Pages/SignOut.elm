module Pages.SignOut exposing (Model, Msg, page)

import Gen.Params.SignOut exposing (Params)
import Gen.Route as Route
import Html as H
import Html.Attributes as A
import Http
import Page
import RemoteData exposing (WebData)
import Request
import Shared
import Util exposing (httpErrorToString)
import View exposing (View)
import W.Container
import W.Loading
import W.Styles


page : Shared.Model -> Request.With Params -> Page.With Model Msg
page shared _ =
    Page.element
        { init = init shared
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- INIT


type alias Model =
    { logoutRequest : WebData String }


init : Shared.Model -> ( Model, Cmd Msg )
init sharedModel =
    ( { logoutRequest = RemoteData.NotAsked }, sendSignOut sharedModel )


sendSignOut : Shared.Model -> Cmd Msg
sendSignOut sharedModel =
    Http.get
        { url = sharedModel.baseUrl ++ "/api/logout"
        , expect = Http.expectString (RemoteData.fromResult >> GotLogoutResponse)
        }



-- UPDATE


type Msg
    = GotLogoutResponse (WebData String)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotLogoutResponse data ->
            ( { model | logoutRequest = data }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Signing Out..."
    , body =
        [ H.div []
            [ W.Styles.globalStyles
            , W.Styles.baseTheme
            , W.Container.view [ W.Container.vertical, W.Container.alignCenterX ]
                (signOutView model)
            ]
        ]
    }


signOutView : Model -> List (H.Html Msg)
signOutView model =
    case model.logoutRequest of
        RemoteData.NotAsked ->
            signOutSpinner

        RemoteData.Loading ->
            signOutSpinner

        RemoteData.Failure e ->
            [ H.text ("Something went wrong: " ++ httpErrorToString e)
            ]

        RemoteData.Success _ ->
            [ H.p [] [ H.text "You are now signed out." ]
            , H.p [] [ H.a [ A.href (Route.toHref Route.SignIn) ] [ H.text "Sign-In" ] ]
            ]


signOutSpinner : List (H.Html Msg)
signOutSpinner =
    [ W.Loading.circles [ W.Loading.size 60 ] ]
