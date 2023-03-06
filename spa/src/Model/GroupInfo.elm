module Model.GroupInfo exposing (GroupInfo, decoder, encoder, name, new, policyStatements)

import Into as I
import Json.Decode as D exposing (Decoder, list, maybe)
import Json.Decode.Pipeline exposing (optional, required)
import Json.Encode as E exposing (Value)
import Model.PolicyStatement as PolicyStatement exposing (PolicyStatement)
import Util exposing (flattenMaybeList)


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


encoder : GroupInfo -> Value
encoder u =
    E.object
        (flattenMaybeList
            [ Just ( "name", E.string u.name )
            , Maybe.map (\v -> ( "description", E.string v )) u.description
            , Just ( "policy_statements", E.list PolicyStatement.encoder u.policyStatements )
            ]
        )


new : GroupInfo
new =
    { name = ""
    , description = Nothing
    , policyStatements = []
    }



-- Into


policyStatements : I.Into GroupInfo (List PolicyStatement)
policyStatements =
    I.Lens .policyStatements (\v o -> { o | policyStatements = v })


name : I.Into GroupInfo String
name =
    I.Lens .name (\v o -> { o | name = v })
