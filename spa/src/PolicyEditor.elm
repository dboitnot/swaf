module PolicyEditor exposing (IndexedStatement(..), Msg(..), UpdateResult(..), update, view)

import Html as H
import Model exposing (PolicyEffect, PolicyStatement, policyEffectToString)
import W.Button
import W.Container
import W.InputField
import W.InputRadio
import W.InputTextArea
import W.Modal


type Msg
    = EffectChanged PolicyEffect
    | ActionsChanged String
    | ResourcesChanged String
    | InputBlurred
    | OkClicked
    | CancelClicked
    | DeleteClicked


type UpdateResult
    = Updated IndexedStatement
    | Saved
    | Cancelled
    | Deleted Int
    | NoResult


type IndexedStatement
    = None
    | At Int PolicyStatement


update : IndexedStatement -> Msg -> UpdateResult
update istm msg =
    case istm of
        None ->
            NoResult

        At i s ->
            doUpdate msg i s


doUpdate : Msg -> Int -> PolicyStatement -> UpdateResult
doUpdate msg idx stmt =
    let
        indexed : PolicyStatement -> IndexedStatement
        indexed =
            At idx

        updated : PolicyStatement -> UpdateResult
        updated =
            \s -> Updated (indexed s)
    in
    case msg of
        EffectChanged e ->
            updated { stmt | effect = e }

        ActionsChanged s ->
            updated { stmt | actions = String.lines s }

        ResourcesChanged s ->
            updated { stmt | resources = String.lines s }

        InputBlurred ->
            cleanStatement stmt |> updated

        OkClicked ->
            Saved

        CancelClicked ->
            Cancelled

        DeleteClicked ->
            Deleted idx


cleanStatement : PolicyStatement -> PolicyStatement
cleanStatement stm =
    { stm | actions = cleanList stm.actions, resources = cleanList stm.resources }


cleanList : List String -> List String
cleanList l =
    List.map String.trim l
        |> List.filter (\s -> not (String.isEmpty s))


view : (Msg -> msg) -> PolicyStatement -> H.Html msg
view wrapperMsg stmt =
    W.Modal.view []
        { isOpen = True
        , onClose = Nothing
        , content =
            [ W.Container.view [ W.Container.vertical, W.Container.pad_4 ]
                [ W.InputRadio.view []
                    { id = "policyStatementEffect"
                    , value = stmt.effect
                    , options = [ Model.Allow, Model.Deny ]
                    , toValue = policyEffectToString
                    , toLabel = policyEffectToString
                    , onInput = \e -> wrapperMsg (EffectChanged e)
                    }
                , stringListView "Actions" ActionsChanged wrapperMsg stmt.actions
                , stringListView "Resources" ResourcesChanged wrapperMsg stmt.resources
                , W.Container.view [ W.Container.horizontal, W.Container.alignRight, W.Container.gap_2 ]
                    [ W.Button.view [] { label = [ H.text "Cancel" ], onClick = wrapperMsg CancelClicked }
                    , W.Button.view [ W.Button.primary ] { label = [ H.text "Ok" ], onClick = wrapperMsg OkClicked }
                    ]
                ]
            ]
        }


stringListView : String -> (String -> Msg) -> (Msg -> msg) -> List String -> H.Html msg
stringListView label stringMsg wrapperMsg items =
    W.InputField.view [ W.InputField.hint [ H.text "Use '*' for wildcard, put items on separate lines." ] ]
        { label = [ H.text label ]
        , input =
            [ W.InputTextArea.view
                [ W.InputTextArea.resizable True
                , W.InputTextArea.rows 3
                , W.InputTextArea.autogrow True
                , W.InputTextArea.onBlur
                    (wrapperMsg InputBlurred)
                ]
                { value = String.join "\n" items
                , onInput = \s -> stringMsg s |> wrapperMsg
                }
            ]
        }
