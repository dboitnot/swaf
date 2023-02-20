module Model.PolicyEffect exposing (PolicyEffect(..), decoder, encoder, toString)

import Json.Decode as D exposing (Decoder, andThen)
import Json.Encode as E exposing (Value)


type PolicyEffect
    = Allow
    | Deny


decoder : Decoder PolicyEffect
decoder =
    D.string |> andThen fromString


encoder : PolicyEffect -> Value
encoder e =
    E.string (toString e)


fromString : String -> Decoder PolicyEffect
fromString effect =
    case effect of
        "Allow" ->
            D.succeed Allow

        "Deny" ->
            D.succeed Deny

        _ ->
            D.fail <| "Unrecognized policy effect: " ++ effect


toString : PolicyEffect -> String
toString e =
    case e of
        Allow ->
            "Allow"

        Deny ->
            "Deny"
