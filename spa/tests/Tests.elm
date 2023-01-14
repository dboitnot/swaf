module Tests exposing (suite)

import Expect
import Json.Decode as Decode
import Model
import Test exposing (Test, describe, test)



-- npx elm-test-rs


suite : Test
suite =
    describe "The Model module"
        [ describe "User JSON decoder"
            [ test "parses a user with a full name" <|
                \_ ->
                    Expect.equal (Ok { loginName = "testUser", fullName = Just "A Test User" })
                        (Decode.decodeString
                            Model.userDecoder
                            """{ "login_name": "testUser", "full_name": "A Test User" }"""
                        )
            , test "parses a user without a full name" <|
                \_ ->
                    Expect.equal (Ok { loginName = "testUser", fullName = Nothing })
                        (Decode.decodeString
                            Model.userDecoder
                            """{ "login_name": "testUser" }"""
                        )
            ]
        ]
