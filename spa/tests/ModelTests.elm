module ModelTests exposing (suite)

import Expect
import Json.Decode as Decode
import Json.Encode exposing (Value)
import Model.PolicyEffect exposing (PolicyEffect(..))
import Model.UserInfo as UserInfo exposing (UserInfo)
import Test exposing (Test, describe, test)



-- npx elm-test-rs


userA : UserInfo
userA =
    { loginName = "usera"
    , fullName = Just "User A"
    , groups = [ "groupa", "groupb" ]
    , policyStatements =
        [ { effect = Allow
          , actions = [ "*" ]
          , resources = [ "*" ]
          }
        ]
    }


suite : Test
suite =
    describe "The Model module"
        [ describe "UserInfo Encoding/Decoding"
            [ test "parses a user with a full name" <|
                \_ ->
                    let
                        encoded : Value
                        encoded =
                            UserInfo.encoder userA

                        decoded : Result Decode.Error UserInfo
                        decoded =
                            Decode.decodeValue UserInfo.decoder encoded
                    in
                    Expect.equal (Ok userA) decoded
            ]
        ]
