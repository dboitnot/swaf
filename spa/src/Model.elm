module Model exposing (User, userDecoder)

import Json.Decode as Decode exposing (Decoder, maybe, string)
import Json.Decode.Pipeline exposing (optional, required)


type alias User =
    { loginName : String
    , fullName : Maybe String
    }


userDecoder : Decoder User
userDecoder =
    Decode.succeed User
        |> required "login_name" string
        |> optional "full_name" (maybe string) Nothing



-- |> optional "full_name" string
