module PolicyEditor exposing (IndexedStatement, Msg(..), indexedView, update)

import Html as H
import Indexed exposing (Indexed)
import Into as I
import Model.PolicyEffect as PolicyEffect exposing (PolicyEffect(..))
import Model.PolicyStatement as PolicyStatement exposing (PolicyStatement)
import Util exposing (deleteInList)
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


type alias IndexedStatement =
    Indexed PolicyStatement


indexedView : (Msg -> msg) -> IndexedStatement -> H.Html msg
indexedView wrapperMsg idx =
    Indexed.item idx
        |> Maybe.map (view wrapperMsg)
        |> Maybe.withDefault (H.text "")


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
                    , options = [ Allow, Deny ]
                    , toValue = PolicyEffect.toString
                    , toLabel = PolicyEffect.toString
                    , onInput = \e -> wrapperMsg (EffectChanged e)
                    }
                , stringListView "Actions" ActionsChanged wrapperMsg stmt.actions
                , stringListView "Resources" ResourcesChanged wrapperMsg stmt.resources
                , W.Container.view [ W.Container.horizontal, W.Container.spaceBetween ]
                    [ W.Button.view
                        [ W.Button.danger ]
                        { label = [ H.text "Delete" ], onClick = wrapperMsg DeleteClicked }
                    , W.Container.view [ W.Container.horizontal, W.Container.alignRight, W.Container.gap_2 ]
                        [ W.Button.view [] { label = [ H.text "Cancel" ], onClick = wrapperMsg CancelClicked }
                        , W.Button.view [ W.Button.primary ] { label = [ H.text "Ok" ], onClick = wrapperMsg OkClicked }
                        ]
                    ]
                ]
            ]
        }


update : I.Into model IndexedStatement -> I.Into model (List PolicyStatement) -> model -> Msg -> model
update openStm stmList model msg =
    let
        intoOpenStm : I.Zipper PolicyStatement model
        intoOpenStm =
            I.into model |> I.thenInto openStm |> I.thenInto Indexed.itemOpt

        curStm : I.Zipper IndexedStatement model
        curStm =
            I.into model |> I.thenInto openStm

        stopEditing : model
        stopEditing =
            I.into model |> I.thenInto openStm |> I.set Indexed.None
    in
    case msg of
        EffectChanged e ->
            intoOpenStm
                |> I.thenInto PolicyStatement.effect
                |> I.set e

        ActionsChanged s ->
            intoOpenStm
                |> I.thenInto PolicyStatement.actions
                |> I.set (String.lines s)

        ResourcesChanged s ->
            intoOpenStm
                |> I.thenInto PolicyStatement.resources
                |> I.set (String.lines s)

        InputBlurred ->
            intoOpenStm |> I.map cleanStatement

        OkClicked ->
            I.into stopEditing
                |> I.thenInto stmList
                |> I.map2 curStm Indexed.setInList

        CancelClicked ->
            stopEditing

        DeleteClicked ->
            I.into stopEditing
                |> I.thenInto stmList
                |> I.map2 (curStm |> I.thenInto Indexed.indexOpt) (\lst idx -> deleteInList idx lst)


cleanStatement : PolicyStatement -> PolicyStatement
cleanStatement stm =
    { stm | actions = cleanList stm.actions, resources = cleanList stm.resources }


cleanList : List String -> List String
cleanList l =
    List.map String.trim l
        |> List.filter (\s -> not (String.isEmpty s))


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
