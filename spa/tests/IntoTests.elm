module IntoTests exposing (suite)

import Expect
import Into as I exposing (Into(..))
import Test exposing (Test, describe, test)



-- npx elm-test-rs
-- Types


type alias Company =
    { ceo : Person
    , cto : Maybe Person
    , hosting : Hosting
    }


type Hosting
    = Cloud
    | OnPrem Int


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
    | Polymorph Shape


type Shape
    = Blob String
    | Polyhedron String Int



-- Test Data


ceoA : Person
ceoA =
    { pay =
        { salary = 123
        , bonus = Just 23
        }
    , pet = Just Fish
    }


ctoA : Person
ctoA =
    { pay = { salary = 222, bonus = Nothing }
    , pet = Just (Dog "Hal")
    }


ceoB : Person
ceoB =
    { pay =
        { salary = 987
        , bonus = Just 77
        }
    , pet = Just (Polymorph (Blob "Purple"))
    }


companyA : Company
companyA =
    { ceo = ceoA, cto = Just ctoA, hosting = OnPrem 8 }


companyB : Company
companyB =
    { ceo = ceoB, cto = Nothing, hosting = Cloud }


blueDodecahedron : Pet
blueDodecahedron =
    Polymorph (Polyhedron "Blue" 12)


greenBlob : Pet
greenBlob =
    Polymorph (Blob "Green")



-- TESTS


suite : Test
suite =
    describe "The Into module"
        [ describe "Composition Tests"
            [ describe "both present"
                [ describe "lens in lens"
                    [ test "get" <|
                        \_ ->
                            I.into ceoA
                                |> I.thenInto personSalary
                                |> I.value
                                |> Expect.equal (Just 123)
                    , test "set" <|
                        \_ ->
                            let
                                newPerson : Person
                                newPerson =
                                    I.into ceoA
                                        |> I.thenInto personSalary
                                        |> I.set 321
                            in
                            Expect.equal 321 newPerson.pay.salary
                    ]
                , describe "optional in lens"
                    [ test "get" <|
                        \_ ->
                            I.into companyA
                                |> I.thenInto companyRacks
                                |> I.value
                                |> Expect.equal (Just 8)
                    , test "set" <|
                        \_ ->
                            let
                                newCompany : Company
                                newCompany =
                                    I.into companyA
                                        |> I.thenInto companyRacks
                                        |> I.set 20
                            in
                            Expect.equal (OnPrem 20) newCompany.hosting
                    ]
                , describe "optional in optional"
                    [ test "get" <|
                        \_ ->
                            I.into blueDodecahedron
                                |> I.thenInto petFaces
                                |> I.value
                                |> Expect.equal (Just 12)
                    , test "set" <|
                        \_ ->
                            let
                                blueIcosahedron : Pet
                                blueIcosahedron =
                                    I.into blueDodecahedron
                                        |> I.thenInto petFaces
                                        |> I.set 20
                            in
                            Expect.equal (Polymorph (Polyhedron "Blue" 20)) blueIcosahedron
                    ]
                , describe "lens in optional"
                    [ test "get" <|
                        \_ ->
                            I.into blueDodecahedron
                                |> I.thenInto petColor
                                |> I.value
                                |> Expect.equal (Just "Blue")
                    , test "set" <|
                        \_ ->
                            let
                                greenDodecahedron : Pet
                                greenDodecahedron =
                                    I.into blueDodecahedron
                                        |> I.thenInto petColor
                                        |> I.set "Green"
                            in
                            Expect.equal (Polymorph (Polyhedron "Green" 12)) greenDodecahedron
                    ]
                ]
            , describe "inner absent, outer present"
                [ describe "optional in lens"
                    [ test "get" <|
                        \_ ->
                            I.into companyB
                                |> I.thenInto companyRacks
                                |> I.value
                                |> Expect.equal Nothing
                    , test "set" <|
                        \_ ->
                            let
                                newCompany : Company
                                newCompany =
                                    I.into companyB
                                        |> I.thenInto companyRacks
                                        |> I.set 20
                            in
                            Expect.equal Cloud newCompany.hosting
                    ]
                , describe "optional in optional"
                    [ test "get" <|
                        \_ ->
                            I.into greenBlob
                                |> I.thenInto petFaces
                                |> I.value
                                |> Expect.equal Nothing
                    , test "set" <|
                        \_ ->
                            let
                                sameBlob : Pet
                                sameBlob =
                                    I.into greenBlob
                                        |> I.thenInto petFaces
                                        |> I.set 20
                            in
                            Expect.equal greenBlob sameBlob
                    ]
                ]
            ]
        , describe "End-to-End Tests"
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


hosting : Into Company Hosting
hosting =
    Lens .hosting (\v o -> { o | hosting = v })


racks : Into Hosting Int
racks =
    let
        get : Hosting -> Maybe Int
        get h =
            case h of
                OnPrem r ->
                    Just r

                _ ->
                    Nothing

        set : Int -> Hosting -> Hosting
        set r h =
            case h of
                OnPrem _ ->
                    OnPrem r

                o ->
                    o
    in
    Optional get set


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


petShape : Into Pet Shape
petShape =
    let
        get : Pet -> Maybe Shape
        get p =
            case p of
                Polymorph shape ->
                    Just shape

                _ ->
                    Nothing

        set : Shape -> Pet -> Pet
        set v p =
            case p of
                Polymorph _ ->
                    Polymorph v

                _ ->
                    p
    in
    Optional get set


faces : Into Shape Int
faces =
    let
        get : Shape -> Maybe Int
        get s =
            case s of
                Polyhedron _ i ->
                    Just i

                _ ->
                    Nothing

        set : Int -> Shape -> Shape
        set v s =
            case s of
                Polyhedron c _ ->
                    Polyhedron c v

                _ ->
                    s
    in
    Optional get set


color : Into Shape String
color =
    let
        get : Shape -> String
        get s =
            case s of
                Polyhedron c _ ->
                    c

                Blob c ->
                    c

        set : String -> Shape -> Shape
        set v s =
            case s of
                Polyhedron _ i ->
                    Polyhedron v i

                Blob _ ->
                    Blob v
    in
    Lens get set


pay : Into Person Pay
pay =
    Lens .pay (\v o -> { o | pay = v })


salary : Into Pay Int
salary =
    Lens .salary (\v o -> { o | salary = v })


bonus : Into Pay (Maybe Int)
bonus =
    Lens .bonus (\v o -> { o | bonus = v })



-- Composites


personSalary : Into Person Int
personSalary =
    pay |> I.compose salary


companyRacks : Into Company Int
companyRacks =
    hosting |> I.compose racks


petFaces : Into Pet Int
petFaces =
    petShape |> I.compose faces


petColor : Into Pet String
petColor =
    petShape |> I.compose color
