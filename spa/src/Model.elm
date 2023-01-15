module Model exposing (FileChildren, FileMetadata, UserInfo, fileChildrenDecoder, fileMetadataDecoder, userInfoDecoder)

import Json.Decode as Decode exposing (Decoder, bool, list, maybe, string)
import Json.Decode.Pipeline exposing (optional, required)



-- USER


type alias UserInfo =
    { loginName : String
    , fullName : Maybe String
    }


userInfoDecoder : Decoder UserInfo
userInfoDecoder =
    Decode.succeed UserInfo
        |> required "login_name" string
        |> optional "full_name" (maybe string) Nothing



-- FILE METADATA


type alias FileMetadata =
    { path : String
    , parent : Maybe String
    , fileName : Maybe String
    , isDir : Bool
    , mayRead : Bool
    , mayWrite : Bool
    }


fileMetadataDecoder : Decoder FileMetadata
fileMetadataDecoder =
    Decode.succeed FileMetadata
        |> required "path" string
        |> optional "parent" (maybe string) Nothing
        |> optional "file_name" (maybe string) Nothing
        |> required "is_dir" bool
        |> required "may_read" bool
        |> required "may_write" bool


type alias FileChildren =
    { children : List FileMetadata }


fileChildrenDecoder : Decoder FileChildren
fileChildrenDecoder =
    Decode.succeed FileChildren
        |> required "children" (list fileMetadataDecoder)
