module Model.GroupList exposing (GroupList, decoder)

import Json.Decode as D exposing (Decoder, list)
import Json.Decode.Pipeline exposing (required)
import Model.GroupInfo as GroupInfo exposing (GroupInfo)


type alias GroupList =
    { groups : List GroupInfo }


decoder : Decoder GroupList
decoder =
    D.succeed GroupList
        |> required "groups" (list GroupInfo.decoder)
