module Pages.Home_ exposing (Model, Msg, page)

import Html as H
import Page
import Request exposing (Request)
import Shared
import View exposing (View)
import W.Button
import W.Styles



-- For later:
-- elm install krisajenkins/remotedata


type Msg
    = Clicked


type alias Model =
    { clickCount : Int }


page : Shared.Model -> Request -> Page.With Model Msg
page _ _ =
    Page.sandbox
        { init = init
        , update = update
        , view = view
        }


init : Model
init =
    { clickCount = 0 }


update : Msg -> Model -> Model
update msg model =
    case msg of
        Clicked ->
            { model | clickCount = model.clickCount + 1 }


view : Model -> View Msg
view model =
    { title = "HI there"
    , body =
        [ H.div []
            [ W.Styles.globalStyles
            , W.Styles.baseTheme
            , W.Button.view [] { label = [ H.text ("Hi " ++ String.fromInt model.clickCount) ], onClick = Clicked }
            ]
        ]
    }
