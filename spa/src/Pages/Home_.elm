module Pages.Home_ exposing (Model, Msg, page)

import Html as H
import Http
import Model exposing (FileChildren, FileMetadata, fileChildrenDecoder, fileMetadataDecoder)
import Page
import RemoteData exposing (WebData)
import Request exposing (Request)
import Shared exposing (User)
import View exposing (View)
import W.Styles


type Msg
    = GotMetadata (WebData FileMetadata)
    | GotChildren (WebData FileChildren)


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
        { url = sharedModel.baseUrl ++ "/api/ls" ++ dirPath
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
            , menuBar user model
            , H.br [] []
            , fileDisplay model
            , H.br [] []
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


fileDisplay : Model -> H.Html msg
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


fileDisplayWithMeta : Model -> FileMetadata -> H.Html msg
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


dirListing : Model -> H.Html msg
dirListing model =
    case model.children of
        RemoteData.Success children ->
            dirListingTable children

        _ ->
            dirListingLoading


dirListingTable : FileChildren -> H.Html msg
dirListingTable children =
    H.ul [] (children.children |> List.map dirListingTableEntry)


dirListingTableEntry : FileMetadata -> H.Html msg
dirListingTableEntry meta =
    let
        fileName : String
        fileName =
            case meta.fileName of
                Just name ->
                    name

                Nothing ->
                    "?"
    in
    H.li [] [ H.text fileName ]


dirListingLoading : H.Html msg
dirListingLoading =
    H.text "Dir Listing Loading"



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
