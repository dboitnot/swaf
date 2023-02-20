module Model.GroupInfo exposing (GroupInfo, decoder)

import Json.Decode as D exposing (Decoder, list, maybe)
import Json.Decode.Pipeline exposing (optional, required)
import Model.PolicyStatement as PolicyStatement exposing (PolicyStatement)


type alias GroupInfo =
    { name : String
    , description : Maybe String
    , policyStatements : List PolicyStatement
    }


decoder : Decoder GroupInfo
decoder =
    D.succeed GroupInfo
        |> required "name" D.string
        |> optional "description" (maybe D.string) Nothing
        |> required "policy_statements" (list PolicyStatement.decoder)
