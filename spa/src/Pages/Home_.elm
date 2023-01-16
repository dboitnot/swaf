module Pages.Home_ exposing (Model, Msg, page)

import Browser.Navigation as Nav
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
import Util exposing (boolToMaybe, flattenMaybeList)
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


type alias Model =
    { metadata : WebData FileMetadata
    , children : WebData FileChildren
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
    ( { metadata = RemoteData.NotAsked, children = RemoteData.NotAsked }
    , getMetadata sharedModel ""
    )



-- UPDATE


update : Shared.Model -> Msg -> Model -> ( Model, Cmd Msg )
update sharedModel msg model =
    case msg of
        GotMetadata meta ->
            ( { model | metadata = meta }, updateMetaCmd sharedModel meta )

        GotChildren children ->
            ( { model | children = children }, Cmd.none )

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
    H.div []
        (flattenMaybeList
            [ Just (crumbTrail meta)
            , meta.isDir |> boolToMaybe (dirListing model)
            ]
        )


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


dirListing : Model -> H.Html Msg
dirListing model =
    case model.children of
        RemoteData.Success children ->
            dirListingTable children

        _ ->
            dirListingLoading


dirListingTable : FileChildren -> H.Html Msg
dirListingTable children =
    W.Table.view []
        [ W.Table.column [ W.Table.alignCenter, W.Table.width 20 ] { label = "", content = fileTypeIcon }
        , W.Table.column [] { label = "Name", content = fileNameCell }
        ]
        children.children


fileNameCell : FileMetadata -> H.Html Msg
fileNameCell meta =
    H.span
        [ E.onClick (ChildClicked meta)
        , A.style "cursor" "pointer"
        ]
        [ H.text (Maybe.withDefault "?" meta.fileName) ]


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
        I.download [ I.onClick (DownloadClicked meta) ]

    else
        I.downloadOff []


dirListingLoading : H.Html msg
dirListingLoading =
    H.text "Dir Listing Loading"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
