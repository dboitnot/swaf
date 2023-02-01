module Layout exposing (layout)

import Gen.Route
import Html as H
import Icons
import Shared exposing (User)
import View exposing (View)
import W.Button
import W.Container
import W.Popover
import W.Styles


layout : User -> String -> List (H.Html msg) -> View msg
layout user title body =
    { title = title ++ " [SWAF]"
    , body =
        [ H.div []
            [ W.Styles.globalStyles
            , W.Styles.baseTheme
            , W.Container.view
                [ W.Container.vertical, W.Container.alignCenterX ]
                (menuBar user
                    :: body
                )
            ]
        ]
    }


menuBar : User -> H.Html msg
menuBar user =
    W.Container.view
        [ W.Container.horizontal
        , W.Container.background "#c0c0ff"
        , W.Container.spaceBetween
        , W.Container.styleAttrs [ ( "width", "100%" ) ]
        ]
        [ navMenuButton
        , H.text "SWAF"
        , userMenuButton user
        ]


navMenuButton : H.Html msg
navMenuButton =
    W.Popover.view []
        { content = [ H.text "MenuButton" ]
        , children = [ W.Button.viewDummy [ W.Button.icon, W.Button.invisible ] [ Icons.menu [] ] ]
        }


userMenuButton : User -> H.Html msg
userMenuButton user =
    W.Popover.view [ W.Popover.bottomRight ]
        { content = [ H.text "Hi" ]
        , children = [ W.Button.viewDummy [ W.Button.icon, W.Button.invisible ] [ Icons.accountCircle [] ] ]
        }


userDisplayName : User -> String
userDisplayName user =
    case user.info.fullName of
        Just name ->
            name

        Nothing ->
            user.info.loginName
