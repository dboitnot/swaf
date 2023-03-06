module Api exposing (getGroups, getUsers, saveGroup, saveUser, updatePassword)

import Api.Response as Response exposing (Response)
import Editing exposing (Editing)
import Http exposing (Expect)
import Json.Decode exposing (Decoder)
import Json.Encode exposing (Value)
import Model.GroupInfo as GroupInfo exposing (GroupInfo)
import Model.GroupList as GroupList exposing (GroupList)
import Model.UserInfo as UserInfo exposing (UserInfo)
import Model.UserList as UserList exposing (UserList)
import Shared



-- User API Calls


getUsers : (Response UserList -> msg) -> Shared.Model -> Cmd msg
getUsers msg sharedModel =
    Http.get
        { url = sharedModel.baseUrl ++ "/api/users"
        , expect = expectData UserList.decoder msg
        }



-- createUser : (Response () -> msg) -> Shared.Model -> UserInfo -> Cmd msg
-- createUser =
--     create "user" UserInfo.encoder
-- updateUser : (Response () -> msg) -> Shared.Model -> UserInfo -> Cmd msg
-- updateUser =
--     update "user" UserInfo.encoder


saveUser : (Response () -> msg) -> Shared.Model -> Editing UserInfo -> Cmd msg
saveUser =
    save "user" UserInfo.encoder


updatePassword : (Response () -> msg) -> Shared.Model -> UserInfo -> String -> Cmd msg
updatePassword msg sharedModel user password =
    Http.post
        { url = sharedModel.baseUrl ++ "/api/user/" ++ user.loginName ++ "/password"
        , body = Http.stringBody "text/plain" password
        , expect = expectNothing msg
        }



-- Group API Calls


getGroups : (Response GroupList -> msg) -> Shared.Model -> Cmd msg
getGroups wrapperMsg sharedModel =
    Http.get
        { url = sharedModel.baseUrl ++ "/api/groups"
        , expect = expectData GroupList.decoder wrapperMsg
        }



-- createGroup : (Response () -> msg) -> Shared.Model -> GroupInfo -> Cmd msg
-- createGroup =
--     create "group" GroupInfo.encoder
-- updateGroup : (Response () -> msg) -> Shared.Model -> GroupInfo -> Cmd msg
-- updateGroup =
--     update "group" GroupInfo.encoder


saveGroup : (Response () -> msg) -> Shared.Model -> Editing GroupInfo -> Cmd msg
saveGroup =
    save "group" GroupInfo.encoder



-- Utility Functions


save : String -> (a -> Value) -> (Response () -> msg) -> Shared.Model -> Editing a -> Cmd msg
save kind encoder msg sharedModel edit =
    case edit of
        Editing.Creating o ->
            create kind encoder msg sharedModel o

        Editing.Updating o ->
            update kind encoder msg sharedModel o

        _ ->
            Cmd.none


create : String -> (a -> Value) -> (Response () -> msg) -> Shared.Model -> a -> Cmd msg
create kind encoder msg sharedModel obj =
    httpPut
        { url = sharedModel.baseUrl ++ "/api/" ++ kind
        , body = Http.jsonBody (encoder obj)
        , expect = expectNothing msg
        }


update : String -> (a -> Value) -> (Response () -> msg) -> Shared.Model -> a -> Cmd msg
update kind encoder msg sharedModel obj =
    Http.post
        { url = sharedModel.baseUrl ++ "/api/" ++ kind
        , body = Http.jsonBody (encoder obj)
        , expect = expectNothing msg
        }


expectData : Decoder a -> (Response a -> msg) -> Expect msg
expectData decoder msg =
    decoder |> Http.expectJson (Response.fromResult >> msg)


expectNothing : (Response () -> msg) -> Expect msg
expectNothing msg =
    Http.expectWhatever (Response.fromResult >> msg)


httpPut :
    { url : String
    , body : Http.Body
    , expect : Expect msg
    }
    -> Cmd msg
httpPut conf =
    Http.request
        { url = conf.url
        , method = "PUT"
        , headers = []
        , body = conf.body
        , expect = conf.expect
        , timeout = Nothing
        , tracker = Nothing
        }
