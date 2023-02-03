module Pages.Admin.Users exposing (Model, Msg, SortOn, page)

import CrudView exposing (Editing, ErrorMessage, crudView, editMap, isUpdating)
import Gen.Params.Admin.Users exposing (Params)
import Html as H
import Http
import Model exposing (UserInfo, UserList, userInfoEncoder, userListDecoder)
import Page
import RemoteData exposing (WebData)
import Request
import Shared exposing (User)
import Util
    exposing
        ( authorizedUpdate
        , httpErrorToString
        , maybeEmptyString
        , sortBy
        )
import View exposing (View)
import W.Container
import W.InputField
import W.InputText
import W.Table


page : Shared.Model -> Request.With Params -> Page.With Model Msg
page shared req =
    Page.protected.element
        (\user ->
            { init = init shared
            , update = update shared req
            , view = view user
            , subscriptions = subscriptions
            }
        )



-- INIT


type SortOn
    = Name


type alias Model =
    { users : WebData UserList
    , sortOn : SortOn
    , openUser : Editing UserInfo
    , errorMessage : Maybe (ErrorMessage Msg)
    }


init : Shared.Model -> ( Model, Cmd Msg )
init sharedModel =
    ( { users = RemoteData.NotAsked
      , sortOn = Name
      , openUser = CrudView.NotEditing
      , errorMessage = Nothing
      }
    , getUsers sharedModel
    )



-- UPDATE


type Msg
    = GotUsers (WebData UserList)
    | UserClicked UserInfo
    | StringFieldEdited (UserInfo -> String -> UserInfo) String
    | EditSaveClicked
    | EditCancelled
    | UserUpdated (Result Http.Error ())
    | UpdateErrorCleared


update : Shared.Model -> Request.With Params -> Msg -> Model -> ( Model, Cmd Msg )
update sharedModel req msg model =
    case msg of
        GotUsers users ->
            authorizedUpdate req model users (\_ -> ( { model | users = users |> sorted model }, Cmd.none ))

        UserClicked user ->
            ( { model | openUser = CrudView.Updating user }, Cmd.none )

        StringFieldEdited fn v ->
            ( { model | openUser = editMap fn model.openUser v }, Cmd.none )

        EditSaveClicked ->
            editSaveClicked sharedModel model

        EditCancelled ->
            ( { model | openUser = CrudView.NotEditing }, Cmd.none )

        UserUpdated (Ok _) ->
            ( { model | openUser = CrudView.NotEditing }, getUsers sharedModel )

        UserUpdated (Err e) ->
            ( { model
                | errorMessage =
                    Just
                        { title = "Error Updating User"
                        , message = httpErrorToString e
                        , onAck = UpdateErrorCleared
                        }
              }
            , Cmd.none
            )

        UpdateErrorCleared ->
            ( { model | errorMessage = Nothing }, Cmd.none )


editSaveClicked : Shared.Model -> Model -> ( Model, Cmd Msg )
editSaveClicked sharedModel model =
    case model.openUser of
        CrudView.Creating _ ->
            ( model, Cmd.none )

        CrudView.Updating user ->
            ( { model | openUser = CrudView.UpdateLoading user }, updateUser sharedModel user )

        _ ->
            ( model, Cmd.none )


sorted : Model -> WebData UserList -> WebData UserList
sorted model data =
    RemoteData.map (\users -> { users | users = sorter model users.users }) data


sorter : Model -> (List UserInfo -> List UserInfo)
sorter model =
    let
        cmp : UserInfo -> UserInfo -> Order
        cmp =
            case model.sortOn of
                Name ->
                    sortBy .loginName
    in
    List.sortWith (\a b -> cmp a b)



-- API REQUESTS


getUsers : Shared.Model -> Cmd Msg
getUsers sharedModel =
    Http.get
        { url = sharedModel.baseUrl ++ "/api/users"
        , expect = userListDecoder |> Http.expectJson (RemoteData.fromResult >> GotUsers)
        }


updateUser : Shared.Model -> UserInfo -> Cmd Msg
updateUser sharedModel user =
    Http.post
        { url = sharedModel.baseUrl ++ "/api/user"
        , body = Http.jsonBody (userInfoEncoder user)
        , expect = Http.expectWhatever UserUpdated
        }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : User -> Model -> View Msg
view user model =
    crudView
        { title = "Users"
        , user = user
        , items = model.users
        , listColumns =
            [ W.Table.string [] { label = "Login Name", value = .loginName }
            , W.Table.string [] { label = "Full Name", value = \u -> Maybe.withDefault "<None>" u.fullName }
            ]
        , itemListKey = .users
        , onListClick = UserClicked
        , openItem = model.openUser
        , editView = editView model
        , onSave = EditSaveClicked
        , onCancelEdit = EditCancelled
        , errorMessage = model.errorMessage
        }


editView : Model -> UserInfo -> H.Html Msg
editView model user =
    W.Container.view [ W.Container.vertical ]
        [ textInputField "Login Name"
            [ W.InputText.readOnly (isUpdating model.openUser) ]
            .loginName
            (\u v -> { u | loginName = v })
            user
        , textInputField "Full Name"
            []
            (\u -> Maybe.withDefault "" u.fullName)
            (\u v -> { u | fullName = maybeEmptyString v })
            user
        ]


inputField : String -> H.Html Msg -> H.Html Msg
inputField label input =
    W.InputField.view [] { label = [ H.text label ], input = [ input ] }


textInputField :
    String
    -> List (W.InputText.Attribute Msg)
    -> (UserInfo -> String)
    -> (UserInfo -> String -> UserInfo)
    -> UserInfo
    -> H.Html Msg
textInputField label attrs get set user =
    inputField label
        (W.InputText.view attrs { onInput = StringFieldEdited set, value = get user })
