module CrudView exposing (ErrorMessage, crudView)

import Editing exposing (Editing(..))
import Html as H
import Http
import Icons
import Layout exposing (layout)
import RemoteData exposing (WebData)
import Shared exposing (User)
import Util exposing (flattenMaybeList, httpErrorToString)
import View exposing (View)
import W.Button
import W.Container
import W.Loading
import W.Modal
import W.Notification
import W.Table


type alias ErrorMessage msg =
    { title : String
    , message : String
    , onAck : msg
    }


type alias Conf o r msg =
    { user : User
    , title : String
    , items : WebData r
    , itemListKey : r -> List o
    , buttonBar : List (H.Html msg)
    , listColumns : List (W.Table.Column msg o)
    , openItem : Editing o
    , openItemIsValid : Bool
    , onListClick : o -> msg
    , editView : o -> H.Html msg
    , onSave : msg
    , onCancelEdit : msg
    , errorMessage : Maybe (ErrorMessage msg)
    }


crudView :
    -- We're duplicating the Conf type here to make error messages more helpful.
    { user : User
    , title : String
    , items : WebData r
    , itemListKey : r -> List o
    , buttonBar : List (H.Html msg)
    , listColumns : List (W.Table.Column msg o)
    , openItem : Editing o
    , openItemIsValid : Bool
    , onListClick : o -> msg
    , editView : o -> H.Html msg
    , onSave : msg
    , onCancelEdit : msg
    , errorMessage : Maybe (ErrorMessage msg)
    }
    -> View msg
crudView conf =
    layout conf.user
        conf.title
        (flattenMaybeList
            [ Just (itemListView conf)
            , editView conf
            ]
        )


itemListView : Conf o r msg -> H.Html msg
itemListView conf =
    case conf.items of
        RemoteData.NotAsked ->
            listSpinner

        RemoteData.Loading ->
            listSpinner

        RemoteData.Success data ->
            itemView conf (conf.itemListKey data)

        RemoteData.Failure (Http.BadStatus 403) ->
            errorView "Access Denied" "You are not authorized to view this information."

        RemoteData.Failure e ->
            errorView "Communication Error" (httpErrorToString e)


listSpinner : H.Html msg
listSpinner =
    W.Loading.dots []


errorView : String -> String -> H.Html msg
errorView title detail =
    W.Notification.view [ W.Notification.icon [ Icons.warning [] ], W.Notification.danger ]
        [ H.text detail ]


itemView : Conf o r msg -> List o -> H.Html msg
itemView conf items =
    W.Container.view [ W.Container.vertical ]
        [ W.Container.view [ W.Container.horizontal, W.Container.alignRight, W.Container.pad_2, W.Container.gap_2 ]
            conf.buttonBar
        , itemTable conf items
        ]


itemTable : Conf o r msg -> List o -> H.Html msg
itemTable conf items =
    W.Table.view [ W.Table.onClick conf.onListClick ] conf.listColumns items


editView : Conf o r msg -> Maybe (H.Html msg)
editView conf =
    case conf.openItem of
        NotEditing ->
            Nothing

        Creating o ->
            Just (editModal conf o True)

        Updating o ->
            Just (editModal conf o True)

        CreateLoading o ->
            Just (editModal conf o False)

        UpdateLoading o ->
            Just (editModal conf o False)


editModal : Conf o r msg -> o -> Bool -> H.Html msg
editModal conf o buttonsEnabled =
    W.Modal.view [ W.Modal.htmlAttrs [] ]
        { isOpen = True
        , onClose = Nothing
        , content =
            [ W.Container.view [ W.Container.vertical, W.Container.pad_4 ]
                [ conf.editView o
                , editButtonBar conf buttonsEnabled
                ]
            ]
        }


editButtonBar : Conf o r msg -> Bool -> H.Html msg
editButtonBar conf buttonsEnabled =
    W.Container.view [ W.Container.horizontal, W.Container.alignRight, W.Container.gap_4 ]
        (if buttonsEnabled then
            [ W.Button.view [] { label = [ H.text "Cancel" ], onClick = conf.onCancelEdit }
            , W.Button.view [ W.Button.primary, W.Button.disabled (not conf.openItemIsValid) ]
                { label = [ H.text "Save" ], onClick = conf.onSave }
            ]

         else
            [ W.Loading.dots [] ]
        )
