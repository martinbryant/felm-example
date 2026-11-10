module Page.Login exposing (Model, Msg, init, toSession, update, view)

import Html exposing (Html, a, button, div, h1, p, text)
import Html.Events exposing (onClick)
import Ports
import Route
import Session exposing (Session)


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
        div []
            [ h1 [] [ text "Log in" ]
            , case Session.viewer model.session of
                Just viewer ->
                    p []
                        [ text ("Already logged in as " ++ viewer.name ++ ". ")
                        , a [ Route.href Route.Home ] [ text "Go home" ]
                        ]

                Nothing ->
                    button [ onClick LoginClicked ] [ text "Log in with Keycloak" ]
            ]
    }
