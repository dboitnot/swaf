module IntoTests exposing (suite)

import Expect
import Into as I exposing (Into(..))
import Test exposing (Test, describe, test)



-- npx elm-test-rs
-- Types


type alias Company =
    { ceo : Person
    , cto : Maybe Person
    }


type alias Person =
    { pay : Pay
    , pet : Maybe Pet
    }


type alias Pay =
    { salary : Int
    , bonus : Maybe Int
    }


type Pet
    = Dog String
    | Fish


companyA : Company
companyA =
    { ceo =
        { pay =
            { salary = 123
            , bonus = Just 23
            }
        , pet = Just Fish
        }
    , cto =
        Just
            { pay = { salary = 222, bonus = Nothing }
            , pet = Just (Dog "Hal")
            }
    }



-- TESTS


suite : Test
suite =
    describe "The Into module"
        [ describe "End-to-End Tests"
            [ test "set a record within a record" <|
                \_ ->
                    let
                        newCompany : Company
                        newCompany =
                            I.into companyA
                                |> I.thenInto ceo
                                |> I.thenInto pay
                                |> I.thenInto salary
                                |> I.set 63
                    in
                    Expect.equal 63 newCompany.ceo.pay.salary
            , test "set a Maybe which has a value" <|
                \_ ->
                    let
                        newCompany : Company
                        newCompany =
                            I.into companyA
                                |> I.thenInto ceo
                                |> I.thenInto pay
                                |> I.thenInto bonus
                                |> I.set (Just 88)
                    in
                    Expect.equal (Just 88) newCompany.ceo.pay.bonus
            , test "set a Maybe which has no value" <|
                \_ ->
                    let
                        newCompany : Company
                        newCompany =
                            I.into companyA
                                |> I.thenInto cto
                                |> I.thenIntoMaybe pay
                                |> I.thenInto bonus
                                |> I.set (Just 99)

                        newBonus : Maybe Int
                        newBonus =
                            newCompany.cto
                                |> Maybe.map .pay
                                |> Maybe.andThen .bonus
                    in
                    Expect.equal (Just 99) newBonus
            , test "update a value within an Optional" <|
                \_ ->
                    let
                        newCompany : Company
                        newCompany =
                            I.into companyA
                                |> I.thenInto cto
                                |> I.thenIntoMaybe pet
                                |> I.thenIntoMaybe dogName
                                |> I.set "Louise"

                        newPet : Maybe Pet
                        newPet =
                            newCompany.cto |> Maybe.andThen .pet
                    in
                    Expect.equal (Just (Dog "Louise")) newPet
            , test "update an inapplicable value within an Optional (should be a no-op)" <|
                \_ ->
                    let
                        newCompany : Company
                        newCompany =
                            I.into companyA
                                |> I.thenInto ceo
                                |> I.thenInto pet
                                |> I.thenIntoMaybe dogName
                                |> I.set "Louise"

                        newPet : Maybe Pet
                        newPet =
                            newCompany.ceo.pet
                    in
                    Expect.equal (Just Fish) newPet
            ]
        ]



-- Lenses


ceo : Into Company Person
ceo =
    Lens .ceo (\v o -> { o | ceo = v })


cto : Into Company (Maybe Person)
cto =
    Lens .cto (\v o -> { o | cto = v })


pet : Into Person (Maybe Pet)
pet =
    Lens .pet (\v o -> { o | pet = v })


dogName : Into Pet String
dogName =
    let
        get : Pet -> Maybe String
        get p =
            case p of
                Dog name ->
                    Just name

                _ ->
                    Nothing

        set : String -> Pet -> Pet
        set v p =
            case p of
                Dog _ ->
                    Dog v

                _ ->
                    p
    in
    Optional get set


pay : Into Person Pay
pay =
    Lens .pay (\v o -> { o | pay = v })


salary : Into Pay Int
salary =
    Lens .salary (\v o -> { o | salary = v })


bonus : Into Pay (Maybe Int)
bonus =
    Lens .bonus (\v o -> { o | bonus = v })
