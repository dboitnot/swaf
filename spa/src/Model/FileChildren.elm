module Model.FileChildren exposing (FileChildren, decoder)

import Json.Decode as D exposing (Decoder, list)
import Json.Decode.Pipeline exposing (required)
import Model.FileMetadata as FileMetadata exposing (FileMetadata)


type alias FileChildren =
    { children : List FileMetadata }


decoder : Decoder FileChildren
decoder =
    D.succeed FileChildren
        |> required "children" (list FileMetadata.decoder)
