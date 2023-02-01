module Icons exposing
    ( Attribute
    , Icon
    , accountCircle
    , createNewFolder
    , download
    , downloadOff
    , filled
    , folder
    , grade
    , home
    , icon
    , menu
    , onClick
    , opticalSize
    , size
    , tooltip
    , tooltipText
    , upload
    , uploadOff
    , weight
    )

import Html as H
import Html.Attributes as A
import Html.Events as HE
import Util exposing (boolToMaybe, flattenMaybeList, maybeEmptyString)
import W.Tooltip


type Attribute msg
    = Attribute (Attributes msg -> Attributes msg)


type alias Attributes msg =
    { fill : Maybe Int
    , weight : Maybe Int
    , grade : Maybe Int
    , opticalSize : Maybe Int
    , size : Maybe String
    , onClick : Maybe msg
    , tooltip : Maybe (List (H.Html msg))
    }


defaultAttrs : Attributes msg
defaultAttrs =
    { fill = Nothing
    , weight = Nothing
    , grade = Nothing
    , opticalSize = Nothing
    , size = Nothing
    , onClick = Nothing
    , tooltip = Nothing
    }


applyAttrs : List (Attribute msg) -> Attributes msg
applyAttrs attrs =
    List.foldl (\(Attribute fn) a -> fn a) defaultAttrs attrs



-- ATTRIBUTES


filled : Bool -> Attribute msg
filled v =
    Attribute <| \attrs -> { attrs | fill = boolToMaybe 1 v }


weight : Int -> Attribute msg
weight v =
    Attribute <| \attrs -> { attrs | weight = Just v }


grade : Int -> Attribute msg
grade v =
    Attribute <| \attrs -> { attrs | grade = Just v }


opticalSize : Int -> Attribute msg
opticalSize v =
    Attribute <| \attrs -> { attrs | opticalSize = Just v }


size : String -> Attribute msg
size v =
    Attribute <| \attrs -> { attrs | size = Just v }


onClick : msg -> Attribute msg
onClick v =
    Attribute <| \attrs -> { attrs | onClick = Just v }


tooltip : List (H.Html msg) -> Attribute msg
tooltip tt =
    Attribute <| \attrs -> { attrs | tooltip = Just tt }


tooltipText : String -> Attribute msg
tooltipText txt =
    tooltip [ H.text txt ]



-- ICONS


type alias Icon msg =
    List (Attribute msg) -> H.Html msg


icon : String -> Icon msg
icon name attrList =
    let
        attrs : Attributes msg
        attrs =
            applyAttrs attrList

        span : H.Html msg
        span =
            H.span
                (flattenMaybeList
                    [ Just (A.class "material-symbols-outlined")
                    , style attrs
                    , attrs.onClick |> Maybe.map HE.onClick
                    ]
                )
                [ H.text name ]
    in
    case attrs.tooltip of
        Nothing ->
            span

        Just tt ->
            W.Tooltip.view [ W.Tooltip.fast ]
                { tooltip = tt
                , children = [ span ]
                }


style : Attributes msg -> Maybe (H.Attribute msg)
style attrs =
    [ fontVariationStyle attrs
    , attrs.size |> Maybe.map (\s -> "font-size: " ++ s)
    , attrs.onClick |> Maybe.map (\_ -> "cursor: pointer")
    ]
        |> flattenMaybeList
        |> String.join "; "
        |> maybeEmptyString
        |> Maybe.map (A.attribute "style")


fontVariationStyle : Attributes msg -> Maybe String
fontVariationStyle attrs =
    [ ( .fill, "Fill" ), ( .weight, "wght" ), ( .grade, "GRAD" ), ( .opticalSize, "opsz" ) ]
        |> List.map (\( key, part ) -> fontVariationPart attrs key part)
        |> flattenMaybeList
        |> String.join ", "
        |> maybeEmptyString
        |> Maybe.map (\s -> "font-variation-settings: " ++ s)


fontVariationPart : Attributes msg -> (Attributes msg -> Maybe Int) -> String -> Maybe String
fontVariationPart attrs key part =
    key attrs
        |> Maybe.map String.fromInt
        |> Maybe.map (\v -> "'" ++ part ++ "' " ++ v)



-- Icon Constants
-- https://fonts.google.com/icons


accountCircle : Icon msg
accountCircle =
    icon "account_circle"


createNewFolder : Icon msg
createNewFolder =
    icon "create_new_folder"


download : Icon msg
download =
    icon "download"


downloadOff : Icon msg
downloadOff =
    icon "file_download_off"


folder : Icon msg
folder =
    icon "folder"


home : Icon msg
home =
    icon "home"


logout : Icon msg
logout =
    icon "logout"


menu : Icon msg
menu =
    icon "menu"


upload : Icon msg
upload =
    icon "upload"


uploadOff : Icon msg
uploadOff =
    icon "file_upload_off"
