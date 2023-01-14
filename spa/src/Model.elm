module Model exposing (UserInfo, userInfoDecoder)

import Json.Decode as Decode exposing (Decoder, maybe, string)
import Json.Decode.Pipeline exposing (optional, required)


type alias UserInfo =
    { loginName : String
    , fullName : Maybe String
    }


userInfoDecoder : Decoder UserInfo
userInfoDecoder =
    Decode.succeed UserInfo
        |> required "login_name" string
        |> optional "full_name" (maybe string) Nothing
