module Editing exposing (Editing(..), isCreating, isUpdating, item, itemOpt, map, toLoading)

import Into exposing (Into(..))


type Editing o
    = NotEditing
    | Creating o
    | Updating o
    | CreateLoading o
    | UpdateLoading o


map : (o -> o) -> Editing o -> Editing o
map fn e =
    case e of
        NotEditing ->
            NotEditing

        Creating o ->
            Creating (fn o)

        Updating o ->
            Updating (fn o)

        -- Deny mutation while waiting for server
        _ ->
            e


toLoading : Editing o -> Editing o
toLoading e =
    case e of
        Creating o ->
            CreateLoading o

        Updating o ->
            UpdateLoading o

        _ ->
            e


isUpdating : Editing o -> Bool
isUpdating e =
    case e of
        Updating _ ->
            True

        UpdateLoading _ ->
            True

        _ ->
            False


isCreating : Editing o -> Bool
isCreating e =
    case e of
        Creating _ ->
            True

        CreateLoading _ ->
            True

        _ ->
            False


item : Editing o -> Maybe o
item e =
    case e of
        NotEditing ->
            Nothing

        Creating o ->
            Just o

        Updating o ->
            Just o

        CreateLoading o ->
            Just o

        UpdateLoading o ->
            Just o


itemOpt : Into (Editing o) o
itemOpt =
    let
        set : o -> Editing o -> Editing o
        set o e =
            case e of
                Creating _ ->
                    Creating o

                Updating _ ->
                    Updating o

                _ ->
                    e
    in
    Optional item set
