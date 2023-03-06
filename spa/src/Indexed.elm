module Indexed exposing (Indexed(..), indexOpt, item, itemOpt, setInList)

import Into exposing (Into(..))
import Util exposing (updateListAt)


type Indexed a
    = None
    | At Int a
    | Append a


item : Indexed a -> Maybe a
item i =
    i |> toTuple |> Tuple.second


index : Indexed a -> Maybe Int
index i =
    i |> toTuple |> Tuple.first


itemOpt : Into (Indexed a) a
itemOpt =
    let
        set : a -> Indexed a -> Indexed a
        set a indexed =
            case indexed of
                None ->
                    None

                At i _ ->
                    At i a

                Append _ ->
                    Append a
    in
    Optional item set


indexOpt : Into (Indexed a) Int
indexOpt =
    let
        set : Int -> Indexed a -> Indexed a
        set newIdx indexed =
            case indexed of
                None ->
                    None

                At _ v ->
                    At newIdx v

                Append v ->
                    At newIdx v
    in
    Optional index set


toTuple : Indexed a -> ( Maybe Int, Maybe a )
toTuple indexed =
    case indexed of
        None ->
            ( Nothing, Nothing )

        At idx a ->
            ( Just idx, Just a )

        Append a ->
            ( Nothing, Just a )


setInList : List a -> Indexed a -> List a
setInList lst idx =
    case idx of
        None ->
            lst

        At i v ->
            updateListAt i (always v) lst

        Append v ->
            lst ++ [ v ]
