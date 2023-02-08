module Model exposing
    ( FileChildren
    , FileMetadata
    , GroupInfo
    , GroupList
    , PolicyEffect(..)
    , PolicyStatement
    , UserInfo
    , UserList
    , fileChildrenDecoder
    , fileMetadataDecoder
    , groupInfoDecoder
    , groupListDecoder
    , userInfoDecoder
    , userInfoEncoder
    , userListDecoder
    )

import Json.Decode as D exposing (Decoder, andThen, list, map, maybe)
import Json.Decode.Pipeline exposing (optional, required)
import Json.Encode as E exposing (Value)
import Time
import Util exposing (flattenMaybeList)



-- POLICY


type PolicyEffect
    = Allow
    | Deny


policyEffectDecoder : Decoder PolicyEffect
policyEffectDecoder =
    D.string |> andThen policyEffectFromString


policyEffectEncoder : PolicyEffect -> Value
policyEffectEncoder e =
    E.string (policyEffectToString e)


policyEffectFromString : String -> Decoder PolicyEffect
policyEffectFromString effect =
    case effect of
        "Allow" ->
            D.succeed Allow

        "Deny" ->
            D.succeed Deny

        _ ->
            D.fail <| "Unrecognized policy effect: " ++ effect


policyEffectToString : PolicyEffect -> String
policyEffectToString e =
    case e of
        Allow ->
            "Allow"

        Deny ->
            "Deny"


type alias PolicyStatement =
    { effect : PolicyEffect
    , actions : List String
    , resources : List String
    }


policyStatementDecoder : Decoder PolicyStatement
policyStatementDecoder =
    D.succeed PolicyStatement
        |> required "effect" policyEffectDecoder
        |> required "actions" (list D.string)
        |> required "resources" (list D.string)


policyStatementEncoder : PolicyStatement -> Value
policyStatementEncoder s =
    E.object
        [ ( "effect", policyEffectEncoder s.effect )
        , ( "actions", E.list E.string s.actions )
        , ( "resources", E.list E.string s.resources )
        ]



-- USER


type alias UserInfo =
    { loginName : String
    , fullName : Maybe String
    , groups : List String
    , policyStatements : List PolicyStatement
    }


userInfoDecoder : Decoder UserInfo
userInfoDecoder =
    D.succeed UserInfo
        |> required "login_name" D.string
        |> optional "full_name" (maybe D.string) Nothing
        |> required "groups" (list D.string)
        |> required "policy_statements" (list policyStatementDecoder)


userInfoEncoder : UserInfo -> Value
userInfoEncoder u =
    E.object
        (flattenMaybeList
            [ Just ( "login_name", E.string u.loginName )
            , Maybe.map (\v -> ( "full_name", E.string v )) u.fullName
            , Just ( "groups", E.list E.string u.groups )
            , Just ( "policy_statements", E.list policyStatementEncoder u.policyStatements )
            ]
        )


type alias UserList =
    { users : List UserInfo }


userListDecoder : Decoder UserList
userListDecoder =
    D.succeed UserList
        |> required "users" (list userInfoDecoder)



-- GROUP


type alias GroupInfo =
    { name : String
    , description : Maybe String
    , policyStatements : List PolicyStatement
    }


groupInfoDecoder : Decoder GroupInfo
groupInfoDecoder =
    D.succeed GroupInfo
        |> required "name" D.string
        |> optional "description" (maybe D.string) Nothing
        |> required "policy_statements" (list policyStatementDecoder)


type alias GroupList =
    { groups : List GroupInfo }


groupListDecoder : Decoder GroupList
groupListDecoder =
    D.succeed GroupList
        |> required "groups" (list groupInfoDecoder)



-- FILE METADATA


type alias FileMetadata =
    { path : String
    , parent : Maybe String
    , fileName : Maybe String
    , isDir : Bool
    , mayRead : Bool
    , mayWrite : Bool
    , modified : Maybe Time.Posix
    , sizeBytes : Maybe Int
    }


fileMetadataDecoder : Decoder FileMetadata
fileMetadataDecoder =
    D.succeed FileMetadata
        |> required "path" D.string
        |> optional "parent" (maybe D.string) Nothing
        |> optional "file_name" (maybe D.string) Nothing
        |> required "is_dir" D.bool
        |> required "may_read" D.bool
        |> required "may_write" D.bool
        |> optional "modified" (maybe posix) Nothing
        |> optional "size_bytes" (maybe D.int) Nothing


type alias FileChildren =
    { children : List FileMetadata }


fileChildrenDecoder : Decoder FileChildren
fileChildrenDecoder =
    D.succeed FileChildren
        |> required "children" (list fileMetadataDecoder)



-- More Decoders


posix : Decoder Time.Posix
posix =
    map Time.millisToPosix D.int
