module Ux.TextInputField exposing (Attribute, Conf, readOnly, validationMessage, view)

import Html as H
import Ux.InputField as InputField
import W.InputText


view :
    List (Attribute msg)
    ->
        { value : String
        , label : String
        , onInput : String -> msg
        }
    -> H.Html msg
view attrs args =
    let
        conf : Conf msg
        conf =
            { fieldAttrs = [], inputTextAttrs = [] } |> applyAttrs attrs
    in
    InputField.view args.label
        conf.fieldAttrs
        (W.InputText.view conf.inputTextAttrs { onInput = args.onInput, value = args.value })


type alias Conf msg =
    { fieldAttrs : List InputField.Attribute
    , inputTextAttrs : List (W.InputText.Attribute msg)
    }


type alias Attribute msg =
    Conf msg -> Conf msg


applyAttrs : List (Attribute msg) -> Conf msg -> Conf msg
applyAttrs attrs conf =
    List.foldl (\fn oldConf -> fn oldConf) conf attrs



-- Attributes


validationMessage : Maybe String -> Attribute msg
validationMessage msg conf =
    { conf | fieldAttrs = conf.fieldAttrs ++ [ InputField.validationMessage msg ] }


inputTextAttrs : List (W.InputText.Attribute msg) -> Attribute msg
inputTextAttrs attrs conf =
    { conf | inputTextAttrs = conf.inputTextAttrs ++ attrs }


readOnly : Bool -> Attribute msg
readOnly v =
    inputTextAttrs [ W.InputText.readOnly v ]
