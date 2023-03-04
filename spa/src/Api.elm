module Api exposing (createUser, getGroups, getUsers, updatePassword, updateUser)

import Api.Response as Response exposing (Response)
import Http exposing (Expect)
import Json.Decode exposing (Decoder)
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


getGroups : (Response GroupList -> msg) -> Shared.Model -> Cmd msg
getGroups wrapperMsg sharedModel =
    Http.get
        { url = sharedModel.baseUrl ++ "/api/groups"
        , expect = expectData GroupList.decoder wrapperMsg
        }


createUser : (Response () -> msg) -> Shared.Model -> UserInfo -> Cmd msg
createUser msg sharedModel user =
    Http.request
        { url = sharedModel.baseUrl ++ "/api/user"
        , method = "PUT"
        , headers = []
        , body = Http.jsonBody (UserInfo.encoder user)
        , expect = expectNothing msg
        , timeout = Nothing
        , tracker = Nothing
        }


updateUser : (Response () -> msg) -> Shared.Model -> UserInfo -> Cmd msg
updateUser msg sharedModel user =
    Http.post
        { url = sharedModel.baseUrl ++ "/api/user"
        , body = Http.jsonBody (UserInfo.encoder user)
        , expect = expectNothing msg
        }


updatePassword : (Response () -> msg) -> Shared.Model -> UserInfo -> String -> Cmd msg
updatePassword msg sharedModel user password =
    Http.post
        { url = sharedModel.baseUrl ++ "/api/user/" ++ user.loginName ++ "/password"
        , body = Http.stringBody "text/plain" password
        , expect = expectNothing msg
        }



-- Utility Functions


expectData : Decoder a -> (Response a -> msg) -> Expect msg
expectData decoder msg =
    decoder |> Http.expectJson (Response.fromResult >> msg)


expectNothing : (Response () -> msg) -> Expect msg
expectNothing msg =
    Http.expectWhatever (Response.fromResult >> msg)
