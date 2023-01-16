module Pages.Home_ exposing (Model, Msg, page)

import Browser.Navigation as Nav
import Html as H
import Http
import Icons
import Model exposing (FileChildren, FileMetadata, fileChildrenDecoder, fileMetadataDecoder)
import Page
import RemoteData exposing (WebData)
import Request exposing (Request)
import Shared exposing (User)
import View exposing (View)
import W.Button
import W.Container
import W.Styles
import W.Table


type Msg
    = GotMetadata (WebData FileMetadata)
    | GotChildren (WebData FileChildren)
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
        ([ H.text "Got Metadata"
         , H.br [] []
         ]
            ++ (if meta.isDir then
                    [ dirListing model ]

                else
                    []
               )
        )


dirListing : Model -> H.Html Msg
dirListing model =
    case model.children of
        RemoteData.Success children ->
            dirListingTable children

        _ ->
            dirListingLoading


dirListingTable : FileChildren -> H.Html Msg
dirListingTable children =
    W.Table.view [ W.Table.onClick ChildClicked ]
        [ W.Table.column [ W.Table.alignCenter, W.Table.width 20 ] { label = "", content = fileTypeIcon }
        , W.Table.string [] { label = "Name", value = \meta -> Maybe.withDefault "?" meta.fileName }
        , W.Table.column [ W.Table.alignCenter, W.Table.width 30 ] { label = "", content = fileDownloadIcon }
        ]
        children.children


fileTypeIcon : FileMetadata -> H.Html Msg
fileTypeIcon meta =
    if meta.isDir then
        Icons.folder

    else
        H.text ""


fileDownloadIcon : FileMetadata -> H.Html Msg
fileDownloadIcon meta =
    if meta.isDir then
        H.text ""

    else if meta.mayRead then
        W.Button.view [ W.Button.icon ] { label = [ Icons.download ], onClick = DownloadClicked meta }

    else
        Icons.downloadOff


dirListingLoading : H.Html msg
dirListingLoading =
    H.text "Dir Listing Loading"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
