module PasswordReset exposing (Model, Msg, PasswordState(..), isAcceptable, newModel, update, valid, view)

import Html as H
import Util exposing (flattenMaybeList)
import W.Container
import W.InputText
import W.Message


type alias Model =
    { passwordA : String
    , passwordB : String
    , forceChange : Bool
    }


type Msg
    = PasswordChangeA String
    | PasswordChangeB String


type PasswordState
    = Unchanged
    | Valid String
    | Invalid String


isAcceptable : Model -> Bool
isAcceptable model =
    case stateFrom model of
        Unchanged ->
            True

        Valid _ ->
            True

        Invalid _ ->
            False


valid : Model -> Maybe String
valid model =
    case stateFrom model of
        Unchanged ->
            Nothing

        Valid v ->
            Just v

        Invalid _ ->
            Nothing


newModel : { forceChange : Bool } -> Model
newModel conf =
    { passwordA = "", passwordB = "", forceChange = conf.forceChange }


update : Model -> Msg -> Model
update model msg =
    case msg of
        PasswordChangeA v ->
            { model | passwordA = v }

        PasswordChangeB v ->
            { model | passwordB = v }


stateFrom : Model -> PasswordState
stateFrom model =
    if String.isEmpty model.passwordA && String.isEmpty model.passwordB then
        if model.forceChange then
            Invalid "A password is required"

        else
            Unchanged

    else if model.passwordA /= model.passwordB then
        Invalid "Passwords do not match"

    else if String.length model.passwordA < 8 then
        Invalid "Password must be at least 8 characters"

    else
        Valid model.passwordA


view :
    { wrapperMsg : Msg -> msg
    , model : Model
    }
    -> H.Html msg
view conf =
    W.Container.view [ W.Container.vertical ]
        (flattenMaybeList
            [ Just
                (W.Container.view [ W.Container.inline ]
                    [ pwInput (wrapMsg conf.wrapperMsg PasswordChangeA) conf.model.passwordA
                    , pwInput (wrapMsg conf.wrapperMsg PasswordChangeB) conf.model.passwordB
                    ]
                )
            , messageView conf.model
            ]
        )


wrapMsg : (Msg -> msg) -> (v -> Msg) -> v -> msg
wrapMsg wrapper innerMsg value =
    innerMsg value |> wrapper


pwInput : (String -> msg) -> String -> H.Html msg
pwInput msg value =
    W.InputText.view [ W.InputText.password, W.InputText.placeholder "••••" ] { onInput = msg, value = value }


messageView : Model -> Maybe (H.Html msg)
messageView model =
    case stateFrom model of
        Unchanged ->
            Nothing

        Invalid s ->
            Just (W.Message.view [ W.Message.danger ] [ H.text s ])

        Valid _ ->
            Nothing
