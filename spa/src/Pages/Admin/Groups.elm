module Pages.Admin.Groups exposing (Model, Msg, page)

import Api
import Api.Response as R exposing (Response)
import Cmd.Extra exposing (addCmd, withCmd, withNoCmd)
import CrudView exposing (ErrorMessage, crudView)
import Editing exposing (Editing(..), isCreating, isUpdating)
import Gen.Params.Admin.Groups exposing (Params)
import Gen.Params.Admin.Users exposing (Params)
import Html as H
import Html.Attributes as A
import Http
import Icons
import Indexed
import Into as I exposing (Into(..))
import Model.GroupInfo as GroupInfo exposing (GroupInfo)
import Model.GroupList exposing (GroupList)
import Model.PolicyStatement as PolicyStatement exposing (PolicyStatement)
import Model.UserInfo as UserInfo exposing (UserInfo)
import Model.UserList exposing (UserList)
import Page
import PasswordReset as PR
import PolicyEditor exposing (IndexedStatement)
import PolicyTable
import RemoteData exposing (WebData)
import Request
import Shared exposing (User)
import Util
    exposing
        ( deleteInList
        , flattenMaybeList
        , httpErrorToString
        , maybeEmptyString
        , maybeIs
        , sortBy
        , updateListAt
        )
import View exposing (View)
import W.Button
import W.Container
import W.Divider
import W.InputField
import W.InputText
import W.Menu
import W.Message
import W.Popover
import W.Table
import W.Tag


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


type alias Model =
    { groups : WebData GroupList
    , openGroup : Editing GroupInfo
    , openStatement : IndexedStatement
    , errorMessage : Maybe (ErrorMessage Msg)
    }


openGroup : Into Model (Editing GroupInfo)
openGroup =
    Lens .openGroup (\v m -> { m | openGroup = v })


openGroupStatements : Into Model (List PolicyStatement)
openGroupStatements =
    openGroup |> I.compose Editing.itemOpt |> I.compose GroupInfo.policyStatements


openStatement : Into Model IndexedStatement
openStatement =
    Lens .openStatement (\v m -> { m | openStatement = v })


groups : Into Model (WebData GroupList)
groups =
    Lens .groups (\v m -> { m | groups = v })


init : Shared.Model -> ( Model, Cmd Msg )
init sharedModel =
    ( { groups = RemoteData.NotAsked
      , openGroup = NotEditing
      , openStatement = Indexed.None
      , errorMessage = Nothing
      }
    , getGroups sharedModel
    )



-- UPDATE


type Msg
    = GotGroups (Response GroupList)
    | CreateClicked
    | GroupClicked GroupInfo
    | StringFieldEdited (String -> GroupInfo -> GroupInfo) String
    | PolicyTableClicked Int PolicyStatement
    | AddPolicyClicked
    | PolicyEditorEvent PolicyEditor.Msg
    | EditSaveClicked
    | EditCancelled
    | GroupUpdated (Response ())
    | UpdateErrorCleared


update : Shared.Model -> Request.With Params -> Msg -> Model -> ( Model, Cmd Msg )
update sharedModel req msg model =
    case msg of
        GotGroups response ->
            I.into model |> I.thenInto groups |> R.update req response

        CreateClicked ->
            { model | openGroup = Creating GroupInfo.new } |> withNoCmd

        GroupClicked groupInfo ->
            { model | openGroup = Updating groupInfo } |> withNoCmd

        StringFieldEdited fn v ->
            { model | openGroup = Editing.map (fn v) model.openGroup } |> withNoCmd

        PolicyTableClicked idx stm ->
            { model | openStatement = Indexed.At idx stm } |> withNoCmd

        AddPolicyClicked ->
            { model | openStatement = Indexed.Append PolicyStatement.new } |> withNoCmd

        PolicyEditorEvent e ->
            PolicyEditor.update openStatement openGroupStatements model e |> withNoCmd

        EditSaveClicked ->
            { model | openGroup = Editing.toLoading model.openGroup }
                |> withCmd (Api.saveGroup GroupUpdated sharedModel model.openGroup)

        EditCancelled ->
            ( { model | openGroup = NotEditing }, Cmd.none )

        GroupUpdated res ->
            R.toResult req model res
                |> R.onRemoteError (updateError model "Error updating group")
                |> Result.map (\_ -> ( { model | openGroup = NotEditing }, getGroups sharedModel ))
                |> R.or

        UpdateErrorCleared ->
            ( { model | errorMessage = Nothing }, Cmd.none )


updateError : Model -> String -> Http.Error -> Model
updateError model title err =
    -- TODO: This should be DRY'd
    { model
        | errorMessage =
            Just
                { title = title
                , message = httpErrorToString err
                , onAck = UpdateErrorCleared
                }
    }



-- API REQUESTS


getGroups : Shared.Model -> Cmd Msg
getGroups =
    Api.getGroups GotGroups



-- VIEW


view : User -> Model -> View Msg
view user model =
    -- crudView
    --     { title = "Groups"
    --     , user = user
    --     , items = model.groups
    --     , listColumns = [ W.Table.string [] { label = "Group Name", value = .name } ]
    --     , itemListKey = .groups
    --     , buttonBar = [ W.Button.view [ W.Button.primary ] { label = [ H.text "Create Group" ], onClick = CreateClicked } ]
    --     , onListClick = GroupClicked
    --     , openItem = model.openGroup
    --     , openItemIsValid = openItemIsValid model
    --     , editView = editView model
    --     , onSave = EditSaveClicked
    --     , onCancelEdit = EditCancelled
    --     , errorMessage = model.errorMessage
    --     }
    View.placeholder "Groups"


nameValidationMessage : String -> Maybe String
nameValidationMessage name =
    if String.length name < 1 then
        Just "Group name is required"

    else
        Nothing


openItemIsValid : Model -> Bool
openItemIsValid model =
    Editing.item model.openGroup
        |> Maybe.map .name
        |> Maybe.andThen nameValidationMessage
        |> maybeIs
        |> not



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none
