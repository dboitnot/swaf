module ModelTests exposing (suite)

import Expect
import Json.Decode as Decode
import Json.Encode exposing (Value)
import Model.GroupInfo as GroupInfo exposing (GroupInfo)
import Model.PolicyEffect exposing (PolicyEffect(..))
import Model.PolicyStatement exposing (PolicyStatement)
import Model.UserInfo as UserInfo exposing (UserInfo)
import Test exposing (Test, describe, test)



-- npx elm-test-rs


allowEverything : PolicyStatement
allowEverything =
    { effect = Allow
    , actions = [ "*" ]
    , resources = [ "*" ]
    }


userA : UserInfo
userA =
    { loginName = "usera"
    , fullName = Just "User A"
    , groups = [ "groupa", "groupb" ]
    , policyStatements = [ allowEverything ]
    }


groupA : GroupInfo
groupA =
    { name = "groupa"
    , description = Just "Group A"
    , policyStatements = [ allowEverything ]
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
        , describe "GroupInfo Encoding/Decoding"
            [ test "parses a group with a description" <|
                \_ ->
                    let
                        encoded : Value
                        encoded =
                            GroupInfo.encoder groupA

                        decoded : Result Decode.Error GroupInfo
                        decoded =
                            Decode.decodeValue GroupInfo.decoder encoded
                    in
                    Expect.equal (Ok groupA) decoded
            ]
        ]
