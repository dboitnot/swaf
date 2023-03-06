module Ux.InputField exposing (Attribute, Conf, validationMessage, view)

import Html as H
import Util exposing (flattenMaybeList)
import W.Container
import W.InputField
import W.Message


view : String -> List Attribute -> H.Html msg -> H.Html msg
view label attrs input =
    let
        conf : Conf
        conf =
            { validationMessage = Nothing } |> applyAttrs attrs
    in
    W.InputField.view []
        { label = [ H.text label ]
        , input =
            [ W.Container.view [ W.Container.vertical ]
                (flattenMaybeList
                    [ Just input
                    , conf.validationMessage
                        |> Maybe.map (\m -> W.Message.view [ W.Message.danger ] [ H.text m ])
                    ]
                )
            ]
        }


type alias Conf =
    { validationMessage : Maybe String
    }


type alias Attribute =
    Conf -> Conf


applyAttrs : List Attribute -> Conf -> Conf
applyAttrs attrs conf =
    List.foldl (\fn oldConf -> fn oldConf) conf attrs



-- Attributes


validationMessage : Maybe String -> Attribute
validationMessage msg conf =
    { conf | validationMessage = msg }
