module Model.UserInfo exposing (UserInfo, decoder, encoder)

import Json.Decode as D exposing (Decoder, list, maybe)
import Json.Decode.Pipeline exposing (optional, required)
import Json.Encode as E exposing (Value)
import Model.PolicyStatement as PolicyStatement exposing (PolicyStatement)
import Util exposing (flattenMaybeList)


type alias UserInfo =
    { loginName : String
    , fullName : Maybe String
    , groups : List String
    , policyStatements : List PolicyStatement
    }


decoder : Decoder UserInfo
decoder =
    D.succeed UserInfo
        |> required "login_name" D.string
        |> optional "full_name" (maybe D.string) Nothing
        |> required "groups" (list D.string)
        |> required "policy_statements" (list PolicyStatement.decoder)


encoder : UserInfo -> Value
encoder u =
    E.object
        (flattenMaybeList
            [ Just ( "login_name", E.string u.loginName )
            , Maybe.map (\v -> ( "full_name", E.string v )) u.fullName
            , Just ( "groups", E.list E.string u.groups )
            , Just ( "policy_statements", E.list PolicyStatement.encoder u.policyStatements )
            ]
        )
