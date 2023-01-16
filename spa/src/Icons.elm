module Icons exposing
    ( Attribute
    , download
    , downloadOff
    , filled
    , folder
    , grade
    , icon
    , opticalSize
    , size
    , upload
    , uploadOff
    , weight
    )

import Html as H
import Html.Attributes as A
import Util exposing (boolToMaybe, flattenMaybeList, maybeEmptyString)


type Attribute
    = Attribute (Attributes -> Attributes)


type alias Attributes =
    { fill : Maybe Int
    , weight : Maybe Int
    , grade : Maybe Int
    , opticalSize : Maybe Int
    , size : Maybe String
    }


defaultAttrs : Attributes
defaultAttrs =
    { fill = Nothing
    , weight = Nothing
    , grade = Nothing
    , opticalSize = Nothing
    , size = Nothing
    }


applyAttrs : List Attribute -> Attributes
applyAttrs attrs =
    List.foldl (\(Attribute fn) a -> fn a) defaultAttrs attrs



-- ATTRIBUTES


filled : Bool -> Attribute
filled v =
    Attribute <| \attrs -> { attrs | fill = boolToMaybe 1 v }


weight : Int -> Attribute
weight v =
    Attribute <| \attrs -> { attrs | weight = Just v }


grade : Int -> Attribute
grade v =
    Attribute <| \attrs -> { attrs | grade = Just v }


opticalSize : Int -> Attribute
opticalSize v =
    Attribute <| \attrs -> { attrs | opticalSize = Just v }


size : String -> Attribute
size v =
    Attribute <| \attrs -> { attrs | size = Just v }



-- ICONS


icon : String -> List Attribute -> H.Html msg
icon name attrList =
    let
        attrs : Attributes
        attrs =
            applyAttrs attrList
    in
    H.span
        (flattenMaybeList
            [ style attrs
            , Just (A.class "material-symbols-outlined")
            ]
        )
        [ H.text name ]


style : Attributes -> Maybe (H.Attribute msg)
style attrs =
    [ fontVariationStyle attrs
    , attrs.size |> Maybe.map (\s -> "font-size: " ++ s)
    ]
        |> flattenMaybeList
        |> String.join "; "
        |> maybeEmptyString
        |> Maybe.map (A.attribute "style")


fontVariationStyle : Attributes -> Maybe String
fontVariationStyle attrs =
    [ ( .fill, "Fill" ), ( .weight, "wght" ), ( .grade, "GRAD" ), ( .opticalSize, "opsz" ) ]
        |> List.map (\( key, part ) -> fontVariationPart attrs key part)
        |> flattenMaybeList
        |> String.join ", "
        |> maybeEmptyString
        |> Maybe.map (\s -> "font-variation-settings: " ++ s)


fontVariationPart : Attributes -> (Attributes -> Maybe Int) -> String -> Maybe String
fontVariationPart attrs key part =
    key attrs
        |> Maybe.map String.fromInt
        |> Maybe.map (\v -> "'" ++ part ++ "' " ++ v)


folder : List Attribute -> H.Html msg
folder =
    icon "folder"


download : List Attribute -> H.Html msg
download =
    icon "download"


downloadOff : List Attribute -> H.Html msg
downloadOff =
    icon "file_download_off"


upload : List Attribute -> H.Html msg
upload =
    icon "upload"


uploadOff : List Attribute -> H.Html msg
uploadOff =
    icon "file_upload_off"
