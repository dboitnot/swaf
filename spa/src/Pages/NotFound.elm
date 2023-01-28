module Pages.NotFound exposing (page)

import Gen.Route
import Page exposing (Page)
import Request exposing (Request)
import Shared
import View


page : Shared.Model -> Request -> Page
page _ req =
    Page.element
        { init = init req
        , update = \_ _ -> ( (), Cmd.none )
        , view = \_ -> View.placeholder "Page not found."
        , subscriptions = \_ -> Sub.none
        }


init : Request -> ( (), Cmd msg )
init req =
    let
        path : String
        path =
            req.url.path
    in
    ( ()
    , if path == "/" then
        Request.pushRoute Gen.Route.Browse req

      else
        Cmd.none
    )
