module Model.UserList exposing (UserList, decoder)

import Json.Decode as D exposing (Decoder, list)
import Json.Decode.Pipeline exposing (required)
import Model.UserInfo as UserInfo exposing (UserInfo)


type alias UserList =
    { users : List UserInfo }


decoder : Decoder UserList
decoder =
    D.succeed UserList
        |> required "users" (list UserInfo.decoder)
