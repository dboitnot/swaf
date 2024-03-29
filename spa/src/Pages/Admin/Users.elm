module Pages.Admin.Users exposing (Model, Msg, SortOn, page)

import Api
import Api.Response as R exposing (Response)
import Cmd.Extra exposing (addCmd, withCmd, withNoCmd)
import CrudView exposing (ErrorMessage, crudView)
import Editing exposing (Editing(..), isCreating, isUpdating)
import Gen.Params.Admin.Users exposing (Params)
import Html as H
import Html.Attributes as A
import Http
import Icons
import Indexed
import Into as I exposing (Into(..))
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
import Util exposing (httpErrorToString, maybeEmptyString, maybeIs, sortBy)
import Ux.InputField as InputField
import Ux.TextInputField as TextInputField
import View exposing (View)
import W.Button
import W.Container
import W.Divider
import W.Menu
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


type SortOn
    = Name


type alias Model =
    { users : WebData UserList
    , sortOn : SortOn
    , openUser : Editing UserInfo
    , openStatement : IndexedStatement
    , errorMessage : Maybe (ErrorMessage Msg)
    , allGroups : WebData GroupList
    , pwResetModel : PR.Model
    }


openUser : Into Model (Editing UserInfo)
openUser =
    Lens .openUser (\e m -> { m | openUser = e })


openUserStatements : Into Model (List PolicyStatement)
openUserStatements =
    openUser |> I.compose Editing.itemOpt |> I.compose UserInfo.policyStatements


openStatement : Into Model IndexedStatement
openStatement =
    Lens .openStatement (\v m -> { m | openStatement = v })


users : Into Model (WebData UserList)
users =
    Lens .users (\v m -> { m | users = v })


allGroups : Into Model (WebData GroupList)
allGroups =
    Lens .allGroups (\v m -> { m | allGroups = v })


init : Shared.Model -> ( Model, Cmd Msg )
init sharedModel =
    ( { users = RemoteData.NotAsked
      , sortOn = Name
      , openUser = NotEditing
      , openStatement = Indexed.None
      , errorMessage = Nothing
      , allGroups = RemoteData.NotAsked
      , pwResetModel = PR.newModel { forceChange = False }
      }
    , Cmd.batch [ getUsers sharedModel, Api.getGroups GotGroups sharedModel ]
    )



-- UPDATE


type Msg
    = NoOp
    | GotUsers (Response UserList)
    | GotGroups (Response GroupList)
    | CreateClicked
    | UserClicked UserInfo
    | StringFieldEdited (String -> UserInfo -> UserInfo) String
    | GroupAddClicked String
    | GroupDropClicked String
    | PolicyTableClicked Int PolicyStatement
    | AddPolicyClicked
    | PolicyEditorEvent PolicyEditor.Msg
    | EditSaveClicked
    | EditCancelled
    | UserUpdated (Response ())
    | PasswordUpdated (Response ())
    | UpdateErrorCleared
    | PasswordMsg PR.Msg


update : Shared.Model -> Request.With Params -> Msg -> Model -> ( Model, Cmd Msg )
update sharedModel req msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        GotUsers response ->
            I.into model
                |> I.thenInto users
                |> R.mapUpdate req (sorted model) response

        GotGroups response ->
            -- { model | allGroups = groups } |> withNoCmd
            I.into model
                |> I.thenInto allGroups
                |> R.update req response

        CreateClicked ->
            startEditing model (Creating { loginName = "", fullName = Nothing, groups = [], policyStatements = [] })

        UserClicked user ->
            { model
                | openUser = Updating user
                , pwResetModel = PR.newModel { forceChange = Editing.isCreating model.openUser }
            }
                |> withNoCmd

        StringFieldEdited fn v ->
            { model | openUser = Editing.map (fn v) model.openUser } |> withNoCmd

        GroupAddClicked groupName ->
            { model | openUser = Editing.map (\u -> { u | groups = u.groups ++ [ groupName ] }) model.openUser }
                |> withNoCmd

        GroupDropClicked name ->
            { model | openUser = Editing.map (\u -> { u | groups = List.filter (\n -> n /= name) u.groups }) model.openUser }
                |> withNoCmd

        PolicyTableClicked idx stmt ->
            { model | openStatement = Indexed.At idx stmt } |> withNoCmd

        AddPolicyClicked ->
            { model | openStatement = Indexed.Append PolicyStatement.new } |> withNoCmd

        PolicyEditorEvent e ->
            PolicyEditor.update openStatement openUserStatements model e |> withNoCmd

        EditSaveClicked ->
            { model | openUser = Editing.toLoading model.openUser }
                |> withCmd (Api.saveUser UserUpdated sharedModel model.openUser)

        EditCancelled ->
            ( { model | openUser = NotEditing }, Cmd.none )

        -- UserUpdated
        --   Unauthorized - Redirect
        --   Error - set model.errorMessage
        --   Success -
        --     PR.valid model.pwResetModel - updatePassword, refresh user list
        --     Otherwise model.openUser = NotEditing, refresh user list
        UserUpdated res ->
            R.toResult req model res
                |> R.onRemoteError (updateError model "Error updating user")
                |> Result.map (\_ -> PR.valid model.pwResetModel)
                |> R.andMaybeThen (updatePassword sharedModel model)
                |> R.andMaybeMap (Tuple.pair model)
                |> R.orMaybe ( { model | openUser = NotEditing }, Cmd.none )
                |> Result.map (getUsers sharedModel |> addCmd)
                |> R.or

        PasswordUpdated res ->
            R.toResult req model res
                |> R.onRemoteError (updateError model "Error setting user password")
                |> Result.map (\_ -> ( { model | openUser = NotEditing }, getUsers sharedModel ))
                |> R.or

        UpdateErrorCleared ->
            ( { model | errorMessage = Nothing }, Cmd.none )

        PasswordMsg m ->
            ( { model | pwResetModel = PR.update model.pwResetModel m }, Cmd.none )


startEditing : Model -> Editing UserInfo -> ( Model, Cmd Msg )
startEditing model edit =
    ( { model
        | openUser = edit
        , pwResetModel = PR.newModel { forceChange = isCreating edit }
      }
    , Cmd.none
    )


updateError : Model -> String -> Http.Error -> Model
updateError model title err =
    { model
        | errorMessage =
            Just
                { title = title
                , message = httpErrorToString err
                , onAck = UpdateErrorCleared
                }
    }


sorted : Model -> UserList -> UserList
sorted model ul =
    { ul | users = sorter model ul.users }


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
getUsers =
    Api.getUsers GotUsers


updatePassword : Shared.Model -> Model -> String -> Maybe (Cmd Msg)
updatePassword sharedModel model pass =
    Editing.item model.openUser
        |> Maybe.map (\u -> Api.updatePassword PasswordUpdated sharedModel u pass)


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
            , W.Table.column [] { label = "Groups", content = \u -> groupList Nothing u.groups }
            ]
        , itemListKey = .users
        , buttonBar = [ W.Button.view [ W.Button.primary ] { label = [ H.text "Create User" ], onClick = CreateClicked } ]
        , onListClick = UserClicked
        , openItem = model.openUser
        , openItemIsValid = openItemIsValid model
        , editView = editView model
        , onSave = EditSaveClicked
        , onCancelEdit = EditCancelled
        , errorMessage = model.errorMessage
        }


loginNameValidationMessage : String -> Maybe String
loginNameValidationMessage name =
    if String.length name < 1 then
        Just "Login name is required"

    else
        Nothing


openItemIsValid : Model -> Bool
openItemIsValid model =
    (Editing.item model.openUser
        |> Maybe.map .loginName
        |> Maybe.andThen loginNameValidationMessage
        |> maybeIs
        |> not
    )
        && PR.isAcceptable model.pwResetModel


editView : Model -> UserInfo -> H.Html Msg
editView model user =
    W.Container.view [ W.Container.vertical ]
        [ TextInputField.view
            [ TextInputField.readOnly (isUpdating model.openUser)
            , TextInputField.validationMessage (loginNameValidationMessage user.loginName)
            ]
            { label = "Login Name"
            , value = user.loginName
            , onInput = StringFieldEdited (I.setter UserInfo.loginName)
            }
        , TextInputField.view []
            { label = "Full Name"
            , value = Maybe.withDefault "" user.fullName
            , onInput = StringFieldEdited (\v u -> { u | fullName = maybeEmptyString v })
            }
        , InputField.view "Password" [] (PR.view { wrapperMsg = PasswordMsg, model = model.pwResetModel })
        , InputField.view "Groups" [] (groupList (Just model) user.groups)
        , InputField.view "Permissions"
            []
            (PolicyTable.view
                { onClick = PolicyTableClicked
                , onAdd = AddPolicyClicked
                , policies = user.policyStatements
                }
            )
        , PolicyEditor.indexedView PolicyEditorEvent model.openStatement
        ]



-- GROUP EDITING


groupList : Maybe Model -> List String -> H.Html Msg
groupList maybeModel grps =
    let
        avGroups : Maybe (List String)
        avGroups =
            Maybe.map availableGroupNames maybeModel

        addButton : List (H.Html Msg)
        addButton =
            case avGroups of
                Nothing ->
                    []

                Just [] ->
                    []

                Just someGroups ->
                    [ groupAddTag someGroups ]
    in
    H.div [] (List.map (groupTag (maybeIs maybeModel)) grps ++ addButton)


groupTag : Bool -> String -> H.Html Msg
groupTag dropable name =
    let
        dropper : List (H.Html Msg)
        dropper =
            if dropable then
                [ W.Divider.view [ W.Divider.vertical, W.Divider.margins 3 ] []
                , W.Button.view [ W.Button.invisible, W.Button.small, W.Button.icon ]
                    { label = [ Icons.close [ Icons.size "1em" ] ], onClick = GroupDropClicked name }
                ]

            else
                []
    in
    W.Tag.view groupTagAttrs ([ H.text name ] ++ dropper)


groupTagAttrs : List (W.Tag.Attribute Msg)
groupTagAttrs =
    [ W.Tag.small True, W.Tag.htmlAttrs [ A.style "margin" "1px" ] ]


groupAddTag : List String -> H.Html Msg
groupAddTag groupNames =
    W.Popover.view []
        { content = [ groupAddMenu groupNames ]
        , children = [ W.Tag.viewButton groupTagAttrs { onClick = NoOp, label = [ H.text "+" ] } ]
        }


groupAddMenu : List String -> H.Html Msg
groupAddMenu groupNames =
    W.Menu.view (List.map (\n -> W.Menu.viewButton [] { label = [ H.text n ], onClick = GroupAddClicked n }) groupNames)


availableGroupNames : Model -> List String
availableGroupNames model =
    case model.allGroups of
        RemoteData.Success gl ->
            gl.groups
                |> List.map .name
                |> List.sort

        _ ->
            []
