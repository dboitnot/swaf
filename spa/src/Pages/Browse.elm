module Pages.Browse exposing (Child, Children, ChildrenSortOn, Model, Msg, UploadStatus, page)

import Browser.Navigation as Nav
import Cmd.Extra exposing (withCmd, withNoCmd)
import DateFormat
import Dict
import File exposing (File)
import File.Select as Select
import Gen.Route
import Html as H
import Html.Attributes as A
import Html.Events as E
import Http
import Icons as I
import Layout exposing (layout)
import Model.FileChildren as FileChildren exposing (FileChildren)
import Model.FileMetadata as FileMetadata exposing (FileMetadata)
import Page
import RemoteData exposing (WebData)
import Request exposing (Request)
import Round
import Shared exposing (User)
import Task
import Time
import Url.Builder exposing (relative)
import Util
    exposing
        ( authorizedUpdate
        , boolToMaybe
        , flattenMaybeList
        , formatFileSize
        , httpErrorToString
        , pathJoin
        , sortBy
        , thenSortBy
        )
import View exposing (View)
import W.Button
import W.Container
import W.InputCheckbox
import W.InputField
import W.InputText
import W.Message
import W.Modal
import W.Table


type Msg
    = GotMetadata (WebData FileMetadata)
    | GotChildren (WebData FileChildren)
    | CrumbClicked String
    | ChildClicked Child
    | ChildSelectionChanged Child Bool
    | DownloadClicked FileMetadata
    | UploadClicked
    | UploadSelected File
    | UploadProgress Http.Progress
    | UploadCancelled
    | UploadFinished (Result Http.Error ())
    | UploadAcknowledged
    | MkdirClicked
    | MkdirNameChanged String
    | MkdirAccepted
    | MkdirCancelled
    | MkdirFinished (WebData String)
    | AdjustTimeZone Time.Zone
    | Tick Time.Posix
    | NoOp


type ChildrenSortOn
    = Name
    | Type


type UploadStatus
    = NotUploading
    | Uploading String
    | UploadComplete String (Result Http.Error ())


type alias Child =
    { metadata : FileMetadata
    , selected : Bool
    }


type alias Children =
    { children : List Child }


type alias Model =
    { metadata : WebData FileMetadata
    , children : WebData Children
    , timeZone : Time.Zone
    , time : Time.Posix
    , sortChildrenOn : ChildrenSortOn
    , uploadStatus : UploadStatus
    , uploadProgress : Maybe Http.Progress
    , mkdirName : Maybe String
    , mkdirStatus : WebData String
    }


page : Shared.Model -> Request -> Page.With Model Msg
page sharedModel req =
    Page.protected.element
        (\user ->
            { init = init sharedModel req
            , update = update sharedModel req
            , view = view user
            , subscriptions = subscriptions
            }
        )


init : Shared.Model -> Request -> ( Model, Cmd Msg )
init sharedModel req =
    ( { metadata = RemoteData.NotAsked
      , children = RemoteData.NotAsked
      , timeZone = Time.utc
      , time = Time.millisToPosix 0
      , sortChildrenOn = Type
      , uploadStatus = NotUploading
      , uploadProgress = Nothing
      , mkdirName = Nothing
      , mkdirStatus = RemoteData.NotAsked
      }
    , Cmd.batch
        [ getMetadata sharedModel (req.query |> Dict.get "p" |> Maybe.withDefault "")
        , Task.perform AdjustTimeZone Time.here
        , Task.perform Tick Time.now
        ]
    )



-- UPDATE


update : Shared.Model -> Request -> Msg -> Model -> ( Model, Cmd Msg )
update sharedModel req msg model =
    case msg of
        NoOp ->
            model |> withNoCmd

        AdjustTimeZone newZone ->
            { model | timeZone = newZone } |> withNoCmd

        Tick newTime ->
            { model | time = newTime } |> withNoCmd

        GotMetadata meta ->
            authorizedUpdate req model meta (\_ -> ( { model | metadata = meta }, updateMetaCmd sharedModel meta ))

        GotChildren children ->
            authorizedUpdate req
                model
                children
                (\_ -> { model | children = children |> wrapChildren |> sortChildren model } |> withNoCmd)

        CrumbClicked path ->
            ( { model
                | metadata = RemoteData.NotAsked
                , children = RemoteData.NotAsked
              }
            , pushPathThen req path (getMetadata sharedModel path)
            )

        ChildClicked child ->
            if child.metadata.isDir then
                let
                    meta : WebData FileMetadata
                    meta =
                        RemoteData.Success child.metadata
                in
                ( { model
                    | metadata = meta
                    , children = RemoteData.NotAsked
                  }
                , pushPathThen req child.metadata.path (updateMetaCmd sharedModel meta)
                )

            else
                ( model, download sharedModel child.metadata )

        ChildSelectionChanged child selected ->
            ( { model
                | children =
                    RemoteData.map
                        (\cc -> { cc | children = updateChildSelection child selected cc.children })
                        model.children
              }
            , Cmd.none
            )

        DownloadClicked meta ->
            ( model, download sharedModel meta )

        UploadClicked ->
            ( model, Select.file [ "*/*" ] UploadSelected )

        UploadSelected file ->
            upload sharedModel model file

        UploadProgress progress ->
            { model | uploadProgress = Just progress } |> withNoCmd

        UploadCancelled ->
            ( { model | uploadStatus = NotUploading, uploadProgress = Nothing }
            , case model.uploadStatus of
                Uploading fileName ->
                    Http.cancel fileName

                _ ->
                    Cmd.none
            )

        UploadFinished res ->
            case model.uploadStatus of
                Uploading fileName ->
                    { model | uploadStatus = UploadComplete fileName res, uploadProgress = Nothing }
                        |> withCmd (refresh sharedModel model)

                -- This shouldn't happen
                _ ->
                    { model | uploadStatus = NotUploading, uploadProgress = Nothing } |> withNoCmd

        UploadAcknowledged ->
            { model | uploadStatus = NotUploading, uploadProgress = Nothing } |> withNoCmd

        MkdirClicked ->
            { model | mkdirName = Just "", mkdirStatus = RemoteData.NotAsked } |> withNoCmd

        MkdirNameChanged v ->
            ( { model
                | mkdirName =
                    if (v == "") || validMkdirName v then
                        Just v

                    else
                        model.mkdirName
              }
            , Cmd.none
            )

        MkdirAccepted ->
            mkdirAccepted sharedModel model

        MkdirCancelled ->
            { model | mkdirName = Nothing } |> withNoCmd

        MkdirFinished (RemoteData.Success _) ->
            { model | mkdirName = Nothing }
                |> withCmd (refresh sharedModel model)

        MkdirFinished s ->
            { model | mkdirStatus = s } |> withNoCmd


refresh : Shared.Model -> Model -> Cmd Msg
refresh sharedModel model =
    model.metadata
        |> RemoteData.toMaybe
        |> Maybe.map (\meta -> getChildren sharedModel meta.path)
        |> Maybe.withDefault Cmd.none


pushPathThen : Request -> String -> Cmd Msg -> Cmd Msg
pushPathThen req path cmd =
    Cmd.batch
        [ Nav.pushUrl req.key (relative [ Gen.Route.toHref Gen.Route.Browse ] [ Url.Builder.string "p" path ])
        , cmd
        ]


updateChildSelection : Child -> Bool -> List Child -> List Child
updateChildSelection child selected children =
    List.map
        (\c ->
            if c.metadata.path == child.metadata.path then
                { c | selected = selected }

            else
                c
        )
        children


download : Shared.Model -> FileMetadata -> Cmd Msg
download sharedModel meta =
    Nav.load (sharedModel.baseUrl ++ "/api/file/" ++ meta.path)


mkdirAccepted : Shared.Model -> Model -> ( Model, Cmd Msg )
mkdirAccepted sharedModel model =
    Maybe.map2 (mkdirAcceptedWith sharedModel model) (RemoteData.toMaybe model.metadata) model.mkdirName
        |> Maybe.withDefault ( model, Cmd.none )


mkdirAcceptedWith : Shared.Model -> Model -> FileMetadata -> String -> ( Model, Cmd Msg )
mkdirAcceptedWith sharedModel model meta name =
    ( { model | mkdirStatus = RemoteData.Loading }, mkdir sharedModel (pathJoin meta.path name) )


wrapChildren : WebData FileChildren -> WebData Children
wrapChildren data =
    RemoteData.map
        (\children ->
            { children = List.map (\c -> { metadata = c, selected = False }) children.children
            }
        )
        data


sortChildren : Model -> WebData Children -> WebData Children
sortChildren model data =
    RemoteData.map
        (\children ->
            { children | children = childSorter model children.children }
        )
        data


childSorter : Model -> (List Child -> List Child)
childSorter model =
    let
        cmp : FileMetadata -> FileMetadata -> Order
        cmp =
            case model.sortChildrenOn of
                Name ->
                    sortBy fileNameOf

                Type ->
                    sortBy
                        (\m ->
                            if m.isDir then
                                0

                            else
                                1
                        )
                        |> thenSortBy fileNameOf
    in
    List.sortWith (\a b -> cmp a.metadata b.metadata)


updateMetaCmd : Shared.Model -> WebData FileMetadata -> Cmd Msg
updateMetaCmd sharedModel metaResponse =
    case metaResponse of
        RemoteData.Success meta ->
            if meta.isDir then
                getChildren sharedModel meta.path

            else
                Cmd.none

        _ ->
            Cmd.none



-- API REQUESTS


getMetadata : Shared.Model -> String -> Cmd Msg
getMetadata sharedModel filePath =
    Http.get
        { url = sharedModel.baseUrl ++ "/api/meta/" ++ filePath
        , expect = FileMetadata.decoder |> Http.expectJson (RemoteData.fromResult >> GotMetadata)
        }


getChildren : Shared.Model -> String -> Cmd Msg
getChildren sharedModel dirPath =
    Http.get
        { url = sharedModel.baseUrl ++ "/api/ls/" ++ dirPath
        , expect = FileChildren.decoder |> Http.expectJson (RemoteData.fromResult >> GotChildren)
        }


mkdir : Shared.Model -> String -> Cmd Msg
mkdir sharedModel dirPath =
    Http.request
        { method = "PUT"
        , headers = []
        , url = sharedModel.baseUrl ++ "/api/mkdir/" ++ dirPath
        , body = Http.emptyBody
        , expect = Http.expectString (RemoteData.fromResult >> MkdirFinished)
        , timeout = Nothing
        , tracker = Nothing
        }


upload : Shared.Model -> Model -> File -> ( Model, Cmd Msg )
upload sharedModel model file =
    case model.metadata of
        RemoteData.Success meta ->
            let
                fileName : String
                fileName =
                    File.name file
            in
            ( { model | uploadStatus = Uploading fileName }
            , Http.request
                { method = "PUT"
                , headers = []
                , url = sharedModel.baseUrl ++ "/api/file/" ++ meta.path ++ "/" ++ fileName
                , body = Http.fileBody file
                , expect = Http.expectWhatever UploadFinished
                , timeout = Nothing
                , tracker = Just fileName
                }
            )

        -- This shouldn't happen.
        _ ->
            ( model, Cmd.none )



-- VIEW


view : User -> Model -> View Msg
view user model =
    layout user
        ("/" ++ Maybe.withDefault "<Loading>" (currentPath model))
        (flattenMaybeList
            [ Just (fileDisplay model)
            , uploadModal model
            , mkdirView model
            ]
        )


currentPath : Model -> Maybe String
currentPath model =
    case model.metadata of
        RemoteData.Success meta ->
            Just meta.path

        _ ->
            Nothing


fileDisplay : Model -> H.Html Msg
fileDisplay model =
    case model.metadata of
        RemoteData.NotAsked ->
            H.text "Not Asked"

        RemoteData.Loading ->
            H.text "Loading Metadata"

        RemoteData.Success metadata ->
            fileDisplayWithMeta model metadata

        RemoteData.Failure (Http.BadStatus 403) ->
            H.text "You are not authorized to view this directory."

        RemoteData.Failure _ ->
            H.text "Something went wrong"


fileDisplayWithMeta : Model -> FileMetadata -> H.Html Msg
fileDisplayWithMeta model meta =
    W.Container.view []
        (flattenMaybeList
            [ Just (fileListHeader meta)
            , meta.isDir |> boolToMaybe (dirListing model)
            ]
        )


fileListHeader : FileMetadata -> H.Html Msg
fileListHeader meta =
    W.Container.view
        [ W.Container.gap_2
        , W.Container.largeScreen [ W.Container.spaceBetween, W.Container.horizontal ]
        ]
        [ crumbTrail meta
        , fileToolbar meta
        ]


crumbTrail : FileMetadata -> H.Html Msg
crumbTrail meta =
    let
        parts : List String
        parts =
            if String.length meta.path < 1 then
                []

            else
                String.split "/" meta.path

        pathUpTo : Int -> String -> String
        pathUpTo i _ =
            parts
                |> List.take (i + 1)
                |> String.join "/"
    in
    parts
        |> List.indexedMap pathUpTo
        |> List.map crumb
        |> List.append [ I.home [ I.onClick (CrumbClicked "") ] ]
        |> List.intersperse (H.text "/")
        |> W.Container.view [ W.Container.horizontal, W.Container.inline, W.Container.gap_2 ]


crumb : String -> H.Html Msg
crumb path =
    let
        name : String
        name =
            path |> String.split "/" |> List.reverse |> List.head |> Maybe.withDefault "?"
    in
    H.span
        [ E.onClick (CrumbClicked path)
        , A.style "cursor" "pointer"
        , A.style "text-decoration" "underline"
        ]
        [ H.text name ]


fileToolbar : FileMetadata -> H.Html Msg
fileToolbar meta =
    let
        props : String -> Msg -> String -> List (I.Attribute Msg)
        props allowedTooltip msg deniedTooltip =
            [ I.tooltipText
                (if meta.mayWrite then
                    allowedTooltip

                 else
                    deniedTooltip
                )
            , I.onClick
                (if meta.mayWrite then
                    msg

                 else
                    NoOp
                )
            ]
    in
    W.Container.view [ W.Container.horizontal, W.Container.gap_4 ]
        (if meta.isDir then
            [ I.upload (props "Upload a file" UploadClicked "You are not permitted to upload here.")
            , I.createNewFolder (props "Create a new folder" MkdirClicked "You are not permitted to create a folder here.")
            ]

         else
            []
        )


dirListing : Model -> H.Html Msg
dirListing model =
    case model.children of
        RemoteData.Success children ->
            dirListingTable model children

        _ ->
            dirListingLoading


dirListingTable : Model -> Children -> H.Html Msg
dirListingTable model children =
    W.Table.view
        [ W.Table.onClick (\_ -> NoOp)
        , W.Table.htmlAttrs [ A.style "font-family" "monospace" ]
        ]
        [ W.Table.column [ W.Table.width 20 ] { label = "", content = childCheckBox }
        , W.Table.column [ W.Table.alignCenter, W.Table.width 20 ] { label = "", content = fileTypeIcon }
        , W.Table.column [] { label = "Name", content = fileNameCell }
        , W.Table.string [ W.Table.width 100 ] { label = "Modified", value = fileDate model }
        , W.Table.string [ W.Table.width 100 ] { label = "Size", value = fileSize }
        , W.Table.column [ W.Table.width 50 ] { label = "", content = childToolbar }
        ]
        children.children


childCheckBox : Child -> H.Html Msg
childCheckBox child =
    W.InputCheckbox.view []
        { value = child.selected
        , onInput = ChildSelectionChanged child
        }


fileSize : Child -> String
fileSize child =
    child.metadata.sizeBytes |> Maybe.map formatFileSize |> Maybe.withDefault ""


fileDate : Model -> Child -> String
fileDate model child =
    case child.metadata.modified of
        Nothing ->
            ""

        Just time ->
            let
                fmt : String
                fmt =
                    if Time.toYear model.timeZone time == Time.toYear model.timeZone model.time then
                        "MMM dd HH:mm"

                    else
                        "MMM dd  yyyy"
            in
            DateFormat.format fmt model.timeZone time


fileNameCell : Child -> H.Html Msg
fileNameCell child =
    H.span
        [ E.onClick (ChildClicked child)
        , A.style "cursor" "pointer"
        ]
        [ H.text (fileNameOf child.metadata) ]


fileTypeIcon : Child -> H.Html Msg
fileTypeIcon child =
    if child.metadata.isDir then
        I.folder [ I.onClick (ChildClicked child) ]

    else
        H.text ""


childToolbar : Child -> H.Html Msg
childToolbar child =
    W.Container.view [] [ fileDownloadIcon child.metadata ]


fileDownloadIcon : FileMetadata -> H.Html Msg
fileDownloadIcon meta =
    if meta.isDir then
        H.text ""

    else if meta.mayRead then
        I.download [ I.onClick (DownloadClicked meta), I.tooltipText "Download this file" ]

    else
        I.downloadOff [ I.tooltipText "You are not permitted to download this file." ]


dirListingLoading : H.Html msg
dirListingLoading =
    H.text "Dir Listing Loading"


uploadModal : Model -> Maybe (H.Html Msg)
uploadModal model =
    case model.uploadStatus of
        NotUploading ->
            Nothing

        Uploading fileName ->
            Just (uploadModalActive fileName Nothing model.uploadProgress)

        UploadComplete fileName res ->
            Just (uploadModalActive fileName (Just res) Nothing)


uploadModalActive : String -> Maybe (Result Http.Error ()) -> Maybe Http.Progress -> H.Html Msg
uploadModalActive fileName res progress =
    let
        progressMsg : String
        progressMsg =
            case res of
                Just (Ok _) ->
                    "Done."

                Just (Err _) ->
                    "Error"

                Nothing ->
                    case progress of
                        Just (Http.Sending p) ->
                            formatFileSize p.sent
                                ++ " / "
                                ++ formatFileSize p.size
                                ++ " ("
                                ++ Round.round 1 (Http.fractionSent p * 100.0)
                                ++ "%)"

                        Just (Http.Receiving _) ->
                            "Finishing..."

                        _ ->
                            "..."

        errorMsg : String
        errorMsg =
            case res of
                Just (Err e) ->
                    httpErrorToString e

                _ ->
                    ""
    in
    W.Modal.view []
        { isOpen = True
        , onClose = Nothing
        , content =
            [ W.Container.view [ W.Container.vertical, W.Container.pad_2 ]
                [ H.text ("Uploading " ++ fileName ++ ": " ++ progressMsg)
                , H.text errorMsg
                , uploadModalButton res
                ]
            ]
        }


uploadModalButton : Maybe (Result Http.Error ()) -> H.Html Msg
uploadModalButton res =
    case res of
        Nothing ->
            W.Button.view [] { label = [ H.text "Cancel" ], onClick = UploadCancelled }

        Just (Ok _) ->
            W.Button.view [ W.Button.success ] { label = [ H.text "Ok" ], onClick = UploadAcknowledged }

        Just (Err _) ->
            W.Button.view [ W.Button.warning ] { label = [ H.text "Ok" ], onClick = UploadAcknowledged }


mkdirView : Model -> Maybe (H.Html Msg)
mkdirView model =
    Maybe.map (mkdirDialog model.mkdirStatus) model.mkdirName


mkdirDialog : WebData String -> String -> H.Html Msg
mkdirDialog status name =
    let
        okDisabled : Bool
        okDisabled =
            case status of
                RemoteData.Loading ->
                    True

                _ ->
                    not (validMkdirName name)
    in
    W.Modal.view []
        { isOpen = True
        , onClose = Nothing
        , content =
            [ W.InputField.view []
                { label = [ H.text "Create a new directory:" ]
                , input =
                    [ W.InputText.view [] { onInput = MkdirNameChanged, value = name }
                    , mkdirMessage status
                    , W.Container.view [ W.Container.horizontal, W.Container.alignRight, W.Container.pad_2, W.Container.gap_2 ]
                        [ W.Button.view [] { label = [ H.text "Cancel" ], onClick = MkdirCancelled }
                        , W.Button.view [ W.Button.primary, W.Button.disabled okDisabled ]
                            { label = [ H.text "Create" ], onClick = MkdirAccepted }
                        ]
                    ]
                }
            ]
        }


mkdirMessage : WebData String -> H.Html Msg
mkdirMessage status =
    case status of
        RemoteData.Failure e ->
            W.Message.view [ W.Message.danger ] [ H.text ("Error: " ++ httpErrorToString e) ]

        _ ->
            H.text ""



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        (flattenMaybeList
            [ Just (Time.every 60000 Tick)
            , case model.uploadStatus of
                Uploading tracker ->
                    Just (Http.track tracker UploadProgress)

                _ ->
                    Nothing
            ]
        )



-- Utilities


fileNameOf : FileMetadata -> String
fileNameOf meta =
    Maybe.withDefault "?" meta.fileName


validMkdirName : String -> Bool
validMkdirName name =
    (String.length name > 0) && not (String.contains "/" name)
