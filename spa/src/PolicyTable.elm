module PolicyTable exposing (view)

import Html as H
import Model.PolicyEffect as PolicyEffect
import Model.PolicyStatement exposing (PolicyStatement)
import W.Button
import W.Container
import W.Table


view :
    { onClick : Int -> PolicyStatement -> msg
    , onAdd : msg
    , policies : List PolicyStatement
    }
    -> H.Html msg
view conf =
    W.Container.view [ W.Container.vertical ]
        [ W.Table.view
            [ W.Table.onClick (\t -> conf.onClick (Tuple.first t) (Tuple.second t)) ]
            [ W.Table.string [] { label = "Effect", value = \t -> Tuple.second t |> .effect |> PolicyEffect.toString }
            , stringListColumn "Actions" .actions
            , stringListColumn "Resources" .resources
            ]
            (List.indexedMap Tuple.pair conf.policies)
        , W.Button.view
            [ W.Button.success
            , W.Button.small
            ]
            { label = [ H.text "Add Permission" ], onClick = conf.onAdd }
        ]


stringListColumn :
    String
    -> (PolicyStatement -> List String)
    -> W.Table.Column msg ( Int, PolicyStatement )
stringListColumn label field =
    W.Table.column [] { label = label, content = stringPile field }


stringPile : (PolicyStatement -> List String) -> ( Int, PolicyStatement ) -> H.Html msg
stringPile field rowTuple =
    W.Container.view [ W.Container.vertical ] (List.map (\v -> H.span [] [ H.text v ]) (Tuple.second rowTuple |> field))
