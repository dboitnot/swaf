module Model.PolicyStatement exposing
    ( PolicyStatement
    , decoder
    , encoder
    )

import Json.Decode as D exposing (Decoder, list)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as E exposing (Value)
import Model.PolicyEffect as PolicyEffect exposing (PolicyEffect)


type alias PolicyStatement =
    { effect : PolicyEffect
    , actions : List String
    , resources : List String
    }


decoder : Decoder PolicyStatement
decoder =
    D.succeed PolicyStatement
        |> required "effect" PolicyEffect.decoder
        |> required "actions" (list D.string)
        |> required "resources" (list D.string)


encoder : PolicyStatement -> Value
encoder s =
    E.object
        [ ( "effect", PolicyEffect.encoder s.effect )
        , ( "actions", E.list E.string s.actions )
        , ( "resources", E.list E.string s.resources )
        ]
