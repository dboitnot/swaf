module Into exposing
    ( Into(..)
    , Zipper(..)
    , compose
    , into
    , map
    , map2
    , set
    , setter
    , thenInto
    , thenIntoMaybe
    , unzip
    , value
    )


type Into outer inner
    = Lens (outer -> inner) (inner -> outer -> outer)
    | Optional (outer -> Maybe inner) (inner -> outer -> outer)


compose : Into middle inner -> Into outer middle -> Into outer inner
compose mi om =
    case ( om, mi ) of
        ( Lens getMiddle upOuter, Lens getInner upMiddle ) ->
            Lens (\o -> getInner (getMiddle o))
                (\v o -> upOuter (upMiddle v (getMiddle o)) o)

        ( Lens getMiddle upOuter, Optional getInnerMaybe upMiddle ) ->
            Optional (\o -> getInnerMaybe (getMiddle o))
                (\v o -> upOuter (upMiddle v (getMiddle o)) o)

        ( Optional getMiddleMaybe upOuter, Optional getInnerMaybe upMiddle ) ->
            Optional (\o -> getMiddleMaybe o |> Maybe.andThen getInnerMaybe)
                (\v o ->
                    getMiddleMaybe o
                        |> Maybe.map (upMiddle v)
                        |> Maybe.map (\m -> upOuter m o)
                        |> Maybe.withDefault o
                )

        ( Optional getMiddleMaybe upOuter, Lens getInner upMiddle ) ->
            Optional (\o -> getMiddleMaybe o |> Maybe.map getInner)
                (\v o ->
                    getMiddleMaybe o
                        |> Maybe.map (upMiddle v)
                        |> Maybe.map (\m -> upOuter m o)
                        |> Maybe.withDefault o
                )


setter : Into outer inner -> (inner -> outer -> outer)
setter i =
    case i of
        Lens _ up ->
            up

        Optional _ up ->
            up


type Zipper focus root
    = Zipper focus (focus -> root)
    | Dead root


into : root -> Zipper root root
into root =
    Zipper root identity



-- out : Zipper focus root -> root
-- out zip =
--     case zip of
--         Dead root ->
--             root
--         Zipper focus up ->
--             up focus


value : Zipper focus root -> Maybe focus
value zip =
    case zip of
        Zipper focus _ ->
            Just focus

        Dead _ ->
            Nothing


thenInto : Into focus newFocus -> Zipper focus root -> Zipper newFocus root
thenInto field oldZip =
    case ( field, oldZip ) of
        ( Lens get update, Zipper oldFocus oldUp ) ->
            Zipper (get oldFocus) (\newFocus -> oldUp (update newFocus oldFocus))

        ( Optional getMaybe update, Zipper oldFocus oldUp ) ->
            intoOptional getMaybe update oldFocus oldUp

        ( _, Dead root ) ->
            Dead root


intoOptional : (focus -> Maybe newFocus) -> (newFocus -> focus -> focus) -> focus -> (focus -> root) -> Zipper newFocus root
intoOptional getMaybe update oldFocus oldUp =
    case getMaybe oldFocus of
        Just newFocus ->
            Zipper newFocus (\nf -> oldUp (update nf oldFocus))

        Nothing ->
            Dead (oldUp oldFocus)


thenIntoMaybe : Into focus newFocus -> Zipper (Maybe focus) root -> Zipper newFocus root
thenIntoMaybe field oldZip =
    case oldZip of
        Dead root ->
            Dead root

        Zipper Nothing oldUp ->
            Dead (oldUp Nothing)

        Zipper (Just oldFocus) oldUp ->
            thenInto field (Zipper oldFocus (\newFocus -> oldUp (Just newFocus)))


map : (focus -> focus) -> Zipper focus root -> root
map fn zip =
    case zip of
        Dead root ->
            root

        Zipper focus up ->
            up (fn focus)


map2 : Zipper focusB rootB -> (focusA -> focusB -> focusA) -> Zipper focusA rootA -> rootA
map2 b fn a =
    case ( a, b ) of
        ( Zipper focusA up, Zipper focusB _ ) ->
            up (fn focusA focusB)

        ( Zipper focus up, Dead _ ) ->
            up focus

        ( Dead root, _ ) ->
            root


set : focus -> Zipper focus root -> root
set v =
    map (always v)


unzip : Zipper focus root -> root
unzip =
    map identity



-- listAppend : item -> Zipper (List item) root -> root
-- listAppend item =
--     map (\l -> l ++ [ item ])
