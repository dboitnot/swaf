module Pages.Admin.Users exposing (Model, Msg, SortOn, page)

import CrudView exposing (ErrorMessage, crudView)
import Editing exposing (Editing(..), isCreating, isUpdating)
import Gen.Params.Admin.Users exposing (Params)
import Html as H
import Html.Attributes as A
import Http
import Icons
import Model exposing (GroupList, PolicyStatement, UserInfo, UserList, groupListDecoder, userInfoEncoder, userListDecoder)
import Page
import PasswordReset as PR
import PolicyEditor exposing (IndexedStatement)
import PolicyTable
import RemoteData exposing (WebData)
import Request
import Shared exposing (User)
import Util
    exposing
        ( authorizedUpdate
        , deleteInList
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


init : Shared.Model -> ( Model, Cmd Msg )
init sharedModel =
    ( { users = RemoteData.NotAsked
      , sortOn = Name
      , openUser = NotEditing
      , openStatement = PolicyEditor.None
      , errorMessage = Nothing
      , allGroups = RemoteData.NotAsked
      , pwResetModel = PR.newModel { forceChange = False }
      }
    , Cmd.batch [ getUsers sharedModel, getGroups sharedModel ]
    )



-- UPDATE


type Msg
    = NoOp
    | GotUsers (WebData UserList)
    | GotGroups (WebData GroupList)
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
    | UserUpdated (Result Http.Error ())
    | PasswordUpdated (Result Http.Error ())
    | UpdateErrorCleared
    | PasswordMsg PR.Msg


update : Shared.Model -> Request.With Params -> Msg -> Model -> ( Model, Cmd Msg )
update sharedModel req msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        GotUsers users ->
            authorizedUpdate req model users (\_ -> ( { model | users = users |> sorted model }, Cmd.none ))

        GotGroups groups ->
            ( { model | allGroups = groups }, Cmd.none )

        CreateClicked ->
            startEditing model (Creating { loginName = "", fullName = Nothing, groups = [], policyStatements = [] })

        UserClicked user ->
            ( { model
                | openUser = Updating user
                , pwResetModel = PR.newModel { forceChange = Editing.isCreating model.openUser }
              }
            , Cmd.none
            )

        StringFieldEdited fn v ->
            ( { model | openUser = Editing.map (fn v) model.openUser }, Cmd.none )

        GroupAddClicked groupName ->
            ( { model | openUser = Editing.map (\u -> { u | groups = u.groups ++ [ groupName ] }) model.openUser }, Cmd.none )

        GroupDropClicked name ->
            ( { model | openUser = Editing.map (\u -> { u | groups = List.filter (\n -> n /= name) u.groups }) model.openUser }
            , Cmd.none
            )

        PolicyTableClicked idx stmt ->
            ( { model | openStatement = PolicyEditor.At idx stmt }, Cmd.none )

        PolicyEditorEvent e ->
            ( policyEditorEvent model e, Cmd.none )

        AddPolicyClicked ->
            ( model, Cmd.none )

        EditSaveClicked ->
            editSaveClicked sharedModel model

        EditCancelled ->
            ( { model | openUser = NotEditing }, Cmd.none )

        UserUpdated (Ok _) ->
            userUpdatedSuccess sharedModel model

        UserUpdated (Err e) ->
            updateError model "Error Updating User" e

        PasswordUpdated (Ok _) ->
            editComplete sharedModel model

        PasswordUpdated (Err e) ->
            updateError model "Error Setting User Password" e

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


policyEditorEvent : Model -> PolicyEditor.Msg -> Model
policyEditorEvent model msg =
    let
        save : IndexedStatement -> Model
        save =
            \s -> { model | openStatement = s }
    in
    case PolicyEditor.update model.openStatement msg of
        PolicyEditor.NoResult ->
            model

        PolicyEditor.Updated s ->
            save s

        PolicyEditor.Saved ->
            policyEditorOk model

        PolicyEditor.Cancelled ->
            save PolicyEditor.None

        PolicyEditor.Deleted idx ->
            { model
                | openStatement = PolicyEditor.None
                , openUser = Editing.map (\u -> { u | policyStatements = deleteInList idx u.policyStatements }) model.openUser
            }


policyEditorOk : Model -> Model
policyEditorOk model =
    case model.openStatement of
        PolicyEditor.None ->
            model

        PolicyEditor.At idx stm ->
            { model
                | openStatement = PolicyEditor.None
                , openUser =
                    Editing.map
                        (\u -> { u | policyStatements = updateListAt idx (always stm) u.policyStatements })
                        model.openUser
            }


editSaveClicked : Shared.Model -> Model -> ( Model, Cmd Msg )
editSaveClicked sharedModel model =
    case model.openUser of
        Creating user ->
            ( { model | openUser = CreateLoading user }, createUser sharedModel user )

        Updating user ->
            ( { model | openUser = UpdateLoading user }, updateUser sharedModel user )

        _ ->
            ( model, Cmd.none )


userUpdatedSuccess : Shared.Model -> Model -> ( Model, Cmd Msg )
userUpdatedSuccess sharedModel model =
    let
        up : Maybe ( UserInfo, String )
        up =
            Maybe.map2 (\u p -> ( u, p ))
                (Editing.item model.openUser)
                (PR.valid model.pwResetModel)
    in
    case up of
        Nothing ->
            editComplete sharedModel model

        Just ( user, password ) ->
            ( model, updatePassword sharedModel user password )


editComplete : Shared.Model -> Model -> ( Model, Cmd Msg )
editComplete sharedModel model =
    ( { model | openUser = NotEditing }, getUsers sharedModel )


updateError : Model -> String -> Http.Error -> ( Model, Cmd Msg )
updateError model title err =
    ( { model
        | errorMessage =
            Just
                { title = title
                , message = httpErrorToString err
                , onAck = UpdateErrorCleared
                }
      }
    , Cmd.none
    )


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


getGroups : Shared.Model -> Cmd Msg
getGroups sharedModel =
    Http.get
        { url = sharedModel.baseUrl ++ "/api/groups"
        , expect = groupListDecoder |> Http.expectJson (RemoteData.fromResult >> GotGroups)
        }


createUser : Shared.Model -> UserInfo -> Cmd Msg
createUser sharedModel user =
    Http.request
        { url = sharedModel.baseUrl ++ "/api/user"
        , method = "PUT"
        , headers = []
        , body = Http.jsonBody (userInfoEncoder user)
        , expect = Http.expectWhatever UserUpdated
        , timeout = Nothing
        , tracker = Nothing
        }


updateUser : Shared.Model -> UserInfo -> Cmd Msg
updateUser sharedModel user =
    Http.post
        { url = sharedModel.baseUrl ++ "/api/user"
        , body = Http.jsonBody (userInfoEncoder user)
        , expect = Http.expectWhatever UserUpdated
        }


updatePassword : Shared.Model -> UserInfo -> String -> Cmd Msg
updatePassword sharedModel user password =
    Http.post
        { url = sharedModel.baseUrl ++ "/api/user/" ++ user.loginName ++ "/password"
        , body = Http.stringBody "text/plain" password
        , expect = Http.expectWhatever PasswordUpdated
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
        ([ textInputField "Login Name"
            [ W.InputText.readOnly (isUpdating model.openUser) ]
            .loginName
            (\v u -> { u | loginName = v })
            loginNameValidationMessage
            user
         , textInputField "Full Name"
            []
            (\u -> Maybe.withDefault "" u.fullName)
            (\v u -> { u | fullName = maybeEmptyString v })
            (always Nothing)
            user
         , inputField "Password" (PR.view { wrapperMsg = PasswordMsg, model = model.pwResetModel })
         , inputField "Groups" (groupList (Just model) user.groups)
         , inputField "Permissions"
            (PolicyTable.view
                { onClick = PolicyTableClicked
                , onAdd = AddPolicyClicked
                , policies = user.policyStatements
                }
            )
         ]
            ++ policyEditor model
        )


policyEditor : Model -> List (H.Html Msg)
policyEditor model =
    case model.openStatement of
        PolicyEditor.None ->
            []

        PolicyEditor.At _ stm ->
            [ PolicyEditor.view PolicyEditorEvent stm ]


inputField : String -> H.Html Msg -> H.Html Msg
inputField label input =
    W.InputField.view [] { label = [ H.text label ], input = [ input ] }


validatedInputField : String -> H.Html Msg -> Maybe String -> H.Html Msg
validatedInputField label input validationMessage =
    inputField label
        (W.Container.view [ W.Container.vertical ]
            (flattenMaybeList
                [ Just input
                , validationMessage
                    |> Maybe.map (\m -> W.Message.view [ W.Message.danger ] [ H.text m ])
                ]
            )
        )


textInputField :
    String
    -> List (W.InputText.Attribute Msg)
    -> (UserInfo -> String)
    -> (String -> UserInfo -> UserInfo)
    -> (String -> Maybe String)
    -> UserInfo
    -> H.Html Msg
textInputField label attrs get set validator user =
    let
        value : String
        value =
            get user
    in
    validatedInputField label
        (W.InputText.view attrs { onInput = StringFieldEdited set, value = value })
        (validator value)



-- GROUP EDITING


groupList : Maybe Model -> List String -> H.Html Msg
groupList maybeModel groups =
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
    H.div [] (List.map (groupTag (maybeIs maybeModel)) groups ++ addButton)


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
        RemoteData.Success groups ->
            groups.groups
                |> List.map .name
                |> List.sort

        _ ->
            []
