module Layout exposing (layout)

import Gen.Route exposing (Route)
import Html as H
import Html.Attributes as A
import Icons
import Shared exposing (User)
import View exposing (View)
import W.Button
import W.Container
import W.Menu
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
    W.Popover.view [ W.Popover.htmlAttrs [ A.style "width" "20em" ] ]
        { content = [ navMenu ]
        , children = [ W.Button.viewDummy [ W.Button.icon, W.Button.invisible ] [ Icons.menu [] ] ]
        }


navMenu : H.Html msg
navMenu =
    W.Menu.view
        [ menuLink "Browse Files" Gen.Route.Browse
        , menuTitle "Administration"
        , menuLink "Manage Users" Gen.Route.Admin__Users
        , menuLink "Manage Groups" Gen.Route.Admin__Groups
        ]


userMenuButton : User -> H.Html msg
userMenuButton user =
    W.Popover.view [ W.Popover.bottomRight, W.Popover.htmlAttrs [ A.style "width" "20em" ] ]
        { content = [ userMenu user ]
        , children = [ W.Button.viewDummy [ W.Button.icon, W.Button.invisible ] [ Icons.accountCircle [] ] ]
        }


userMenu : User -> H.Html msg
userMenu user =
    W.Menu.view
        [ menuTitle (userDisplayName user)
        , menuLink "Logout" Gen.Route.SignOut
        ]


userDisplayName : User -> String
userDisplayName user =
    case user.info.fullName of
        Just name ->
            name

        Nothing ->
            user.info.loginName


menuTitle : String -> H.Html msg
menuTitle title =
    W.Menu.viewTitle [] { label = [ H.text title ] }


menuLink : String -> Route -> H.Html msg
menuLink label route =
    W.Menu.viewLink [] { label = [ H.text label ], href = Gen.Route.toHref route }
