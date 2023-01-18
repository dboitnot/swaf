module Pages.Home_ exposing (ChildrenSortOn, Model, Msg, page)

import Browser.Navigation as Nav
import DateFormat
import Html as H
import Html.Attributes as A
import Html.Events as E
import Http
import Icons as I
import Model exposing (FileChildren, FileMetadata, fileChildrenDecoder, fileMetadataDecoder)
import Page
import RemoteData exposing (WebData)
import Request exposing (Request)
import Shared exposing (User)
import Task
import Time
import Util exposing (boolToMaybe, flattenMaybeList, formatFileSize)
import View exposing (View)
import W.Container
import W.Styles
import W.Table


type Msg
    = GotMetadata (WebData FileMetadata)
    | GotChildren (WebData FileChildren)
    | CrumbClicked String
    | ChildClicked FileMetadata
    | DownloadClicked FileMetadata
    | UploadClicked
    | MkdirClicked
    | AdjustTimeZone Time.Zone
    | Tick Time.Posix
    | NoOp


type ChildrenSortOn
    = Name
    | Type


type alias Model =
    { metadata : WebData FileMetadata
    , children : WebData FileChildren
    , timeZone : Time.Zone
    , time : Time.Posix
    , sortChildrenOn : ChildrenSortOn
    }


page : Shared.Model -> Request -> Page.With Model Msg
page sharedModel _ =
    Page.protected.element
        (\user ->
            { init = init sharedModel
            , update = update sharedModel
            , view = view user
            , subscriptions = subscriptions
            }
        )


init : Shared.Model -> ( Model, Cmd Msg )
init sharedModel =
    ( { metadata = RemoteData.NotAsked
      , children = RemoteData.NotAsked
      , timeZone = Time.utc
      , time = Time.millisToPosix 0
      , sortChildrenOn = Type
      }
    , Cmd.batch
        [ getMetadata sharedModel ""
        , Task.perform AdjustTimeZone Time.here
        , Task.perform Tick Time.now
        ]
    )



-- UPDATE


update : Shared.Model -> Msg -> Model -> ( Model, Cmd Msg )
update sharedModel msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        AdjustTimeZone newZone ->
            ( { model | timeZone = newZone }, Cmd.none )

        Tick newTime ->
            ( { model | time = newTime }, Cmd.none )

        GotMetadata meta ->
            ( { model | metadata = meta }, updateMetaCmd sharedModel meta )

        GotChildren children ->
            ( { model | children = sortChildren model children }, Cmd.none )

        CrumbClicked path ->
            ( { model
                | metadata = RemoteData.NotAsked
                , children = RemoteData.NotAsked
              }
            , getMetadata sharedModel path
            )

        ChildClicked childMeta ->
            let
                meta : WebData FileMetadata
                meta =
                    RemoteData.Success childMeta
            in
            ( { model
                | metadata = meta
                , children = RemoteData.NotAsked
              }
            , updateMetaCmd sharedModel meta
            )

        DownloadClicked meta ->
            ( model, Nav.load (sharedModel.baseUrl ++ "/api/file/" ++ meta.path) )

        UploadClicked ->
            ( model, Cmd.none )

        MkdirClicked ->
            ( model, Cmd.none )


sortChildren : Model -> WebData FileChildren -> WebData FileChildren
sortChildren model data =
    case data of
        RemoteData.Success children ->
            RemoteData.Success { children | children = childSorter model children.children }

        _ ->
            data


childSorter : Model -> (List FileMetadata -> List FileMetadata)
childSorter model =
    case model.sortChildrenOn of
        Name ->
            List.sortBy fileNameOf

        Type ->
            List.sortWith
                (\a b ->
                    if a.isDir && b.isDir then
                        LT

                    else if not a.isDir && b.isDir then
                        GT

                    else
                        compare (fileNameOf a) (fileNameOf b)
                )


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
        , expect = fileMetadataDecoder |> Http.expectJson (RemoteData.fromResult >> GotMetadata)
        }


getChildren : Shared.Model -> String -> Cmd Msg
getChildren sharedModel dirPath =
    Http.get
        { url = sharedModel.baseUrl ++ "/api/ls/" ++ dirPath
        , expect = fileChildrenDecoder |> Http.expectJson (RemoteData.fromResult >> GotChildren)
        }



-- VIEW


view : User -> Model -> View Msg
view user model =
    { title = "Hi there"
    , body =
        [ H.div []
            [ W.Styles.globalStyles
            , W.Styles.baseTheme
            , W.Container.view
                [ W.Container.alignCenterX ]
                [ menuBar user model
                , fileDisplay model
                ]
            ]
        ]
    }


menuBar : User -> Model -> H.Html msg
menuBar user _ =
    H.text (userDisplayName user)


userDisplayName : User -> String
userDisplayName user =
    case user.info.fullName of
        Just name ->
            name

        Nothing ->
            user.info.loginName


fileDisplay : Model -> H.Html Msg
fileDisplay model =
    case model.metadata of
        RemoteData.NotAsked ->
            H.text "Not Asked"

        RemoteData.Loading ->
            H.text "Loading Metadata"

        RemoteData.Success metadata ->
            fileDisplayWithMeta model metadata

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


dirListingTable : Model -> FileChildren -> H.Html Msg
dirListingTable model children =
    W.Table.view
        [ W.Table.onClick (\_ -> NoOp)
        , W.Table.htmlAttrs [ A.style "font-family" "monospace" ]
        ]
        [ W.Table.column [ W.Table.alignCenter, W.Table.width 20 ] { label = "", content = fileTypeIcon }
        , W.Table.column [] { label = "Name", content = fileNameCell }
        , W.Table.string [ W.Table.width 100 ] { label = "Modified", value = fileDate model }
        , W.Table.string [ W.Table.width 100 ] { label = "Size", value = fileSize }
        ]
        children.children


fileSize : FileMetadata -> String
fileSize meta =
    meta.sizeBytes |> Maybe.map formatFileSize |> Maybe.withDefault ""


fileDate : Model -> FileMetadata -> String
fileDate model meta =
    case meta.modified of
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


fileNameCell : FileMetadata -> H.Html Msg
fileNameCell meta =
    H.span
        [ E.onClick (ChildClicked meta)
        , A.style "cursor" "pointer"
        ]
        [ H.text (fileNameOf meta) ]


fileTypeIcon : FileMetadata -> H.Html Msg
fileTypeIcon meta =
    if meta.isDir then
        I.folder [ I.onClick (ChildClicked meta) ]

    else
        fileDownloadIcon meta


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



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Time.every 60000 Tick



-- Utilities


fileNameOf : FileMetadata -> String
fileNameOf meta =
    Maybe.withDefault "?" meta.fileName
