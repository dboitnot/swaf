module Model.FileMetadata exposing (FileMetadata, decoder)

import Json.Decode as D exposing (Decoder, map, maybe)
import Json.Decode.Pipeline exposing (optional, required)
import Time


type alias FileMetadata =
    { path : String
    , parent : Maybe String
    , fileName : Maybe String
    , isDir : Bool
    , mayRead : Bool
    , mayWrite : Bool
    , modified : Maybe Time.Posix
    , sizeBytes : Maybe Int
    }


decoder : Decoder FileMetadata
decoder =
    D.succeed FileMetadata
        |> required "path" D.string
        |> optional "parent" (maybe D.string) Nothing
        |> optional "file_name" (maybe D.string) Nothing
        |> required "is_dir" D.bool
        |> required "may_read" D.bool
        |> required "may_write" D.bool
        |> optional "modified" (maybe posix) Nothing
        |> optional "size_bytes" (maybe D.int) Nothing


posix : Decoder Time.Posix
posix =
    map Time.millisToPosix D.int
