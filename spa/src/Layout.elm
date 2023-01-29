module Layout exposing (layout)

import Html as H
import Shared exposing (User)
import View exposing (View)
import W.Container
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
    W.Container.view [ W.Container.horizontal ]
        [ H.text (userDisplayName user)
        ]


userDisplayName : User -> String
userDisplayName user =
    case user.info.fullName of
        Just name ->
            name

        Nothing ->
            user.info.loginName
