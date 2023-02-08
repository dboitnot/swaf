module ModelTests exposing (suite)

import Expect
import Json.Decode as Decode
import Json.Encode exposing (Value)
import Model exposing (UserInfo)
import Test exposing (Test, describe, test)



-- npx elm-test-rs


userA : UserInfo
userA =
    { loginName = "usera"
    , fullName = Just "User A"
    , groups = [ "groupa", "groupb" ]
    , policyStatements =
        [ { effect = Model.Allow
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
                            Model.userInfoEncoder userA

                        decoded : Result Decode.Error UserInfo
                        decoded =
                            Decode.decodeValue Model.userInfoDecoder encoded
                    in
                    Expect.equal (Ok userA) decoded
            ]
        ]
