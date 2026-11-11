module Page.Login exposing (Model, Msg, init, toSession, update, view)

import Html exposing (Html, a, button, div, h1, p, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import Ports
import Route
import Session exposing (Session)
import Ui


type alias Model =
    { session : Session }


type Msg
    = LoginClicked


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session }, Cmd.none )


toSession : Model -> Session
toSession =
    .session


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LoginClicked ->
            ( model, Ports.requestLogin () )


view : Model -> { title : String, content : Html Msg }
view model =
    { title = "Log in"
    , content =
        div [ class "mx-auto max-w-xl" ]
            [ Ui.pageTitle "Log in"
            , Ui.box
                [ case Session.viewer model.session of
                    Just viewer ->
                        p []
                            [ text ("Already logged in as " ++ viewer.name ++ ". ")
                            , a [ Route.href Route.Home, class "text-teal-600 underline" ] [ text "Go home" ]
                            ]

                    Nothing ->
                        button [ Ui.primaryButton, onClick LoginClicked ] [ text "Log in with Keycloak" ]
                ]
            ]
    }
