module Icons exposing
    ( Attribute
    , download
    , downloadOff
    , filled
    , folder
    , grade
    , icon
    , onClick
    , opticalSize
    , size
    , upload
    , uploadOff
    , weight
    )

import Html as H
import Html.Attributes as A
import Html.Events as HE
import Util exposing (boolToMaybe, flattenMaybeList, maybeEmptyString)


type Attribute msg
    = Attribute (Attributes msg -> Attributes msg)


type alias Attributes msg =
    { fill : Maybe Int
    , weight : Maybe Int
    , grade : Maybe Int
    , opticalSize : Maybe Int
    , size : Maybe String
    , onClick : Maybe msg
    }


defaultAttrs : Attributes msg
defaultAttrs =
    { fill = Nothing
    , weight = Nothing
    , grade = Nothing
    , opticalSize = Nothing
    , size = Nothing
    , onClick = Nothing
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



-- ICONS


icon : String -> List (Attribute msg) -> H.Html msg
icon name attrList =
    let
        attrs : Attributes msg
        attrs =
            applyAttrs attrList
    in
    H.span
        (flattenMaybeList
            [ Just (A.class "material-symbols-outlined")
            , style attrs
            , attrs.onClick |> Maybe.map HE.onClick
            ]
        )
        [ H.text name ]


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


folder : List (Attribute msg) -> H.Html msg
folder =
    icon "folder"


download : List (Attribute msg) -> H.Html msg
download =
    icon "download"


downloadOff : List (Attribute msg) -> H.Html msg
downloadOff =
    icon "file_download_off"


upload : List (Attribute msg) -> H.Html msg
upload =
    icon "upload"


uploadOff : List (Attribute msg) -> H.Html msg
uploadOff =
    icon "file_upload_off"
