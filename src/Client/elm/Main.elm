port module Main exposing (main)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (href)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode
import Url
import Url.Parser as Parser exposing (Parser)


type Route
    = Home
    | Login
    | NotFound


type Auth
    = Anonymous
    | Authenticated { name : String, token : String }


type ApiCall
    = Idle
    | Loading
    | Loaded String
    | Failed String


type alias Flags =
    { authenticated : Bool
    , name : String
    , token : String
    }


type alias Model =
    { key : Nav.Key
    , route : Route
    , auth : Auth
    , apiCall : ApiCall
    }


type Msg
    = UrlChanged Url.Url
    | LinkClicked Browser.UrlRequest
    | LoginClicked
    | LogoutClicked
    | TokenRefreshed String
    | GotMe (Result Http.Error String)


port requestLogin : () -> Cmd msg


port requestLogout : () -> Cmd msg


port tokenRefreshed : (String -> msg) -> Sub msg


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> tokenRefreshed TokenRefreshed
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


routeParser : Parser (Route -> a) a
routeParser =
    Parser.oneOf
        [ Parser.map Home Parser.top
        , Parser.map Login (Parser.s "login")
        ]


toRoute : Url.Url -> Route
toRoute url =
    Maybe.withDefault NotFound (Parser.parse routeParser url)


init : Flags -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        auth =
            if flags.authenticated then
                Authenticated { name = flags.name, token = flags.token }

            else
                Anonymous

        model =
            { key = key, route = toRoute url, auth = auth, apiCall = Idle }
    in
    case auth of
        Authenticated { token } ->
            ( { model | apiCall = Loading }, fetchMe token )

        Anonymous ->
            ( model, Cmd.none )


fetchMe : String -> Cmd Msg
fetchMe token =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" ("Bearer " ++ token) ]
        , url = "/api/me"
        , body = Http.emptyBody
        , expect = Http.expectJson GotMe meDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


meDecoder : Decode.Decoder String
meDecoder =
    Decode.field "userId" Decode.string


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        UrlChanged url ->
            ( { model | route = toRoute url }, Cmd.none )

        LinkClicked (Browser.Internal url) ->
            ( model, Nav.pushUrl model.key (Url.toString url) )

        LinkClicked (Browser.External href_) ->
            ( model, Nav.load href_ )

        LoginClicked ->
            ( model, requestLogin () )

        LogoutClicked ->
            ( model, requestLogout () )

        TokenRefreshed token ->
            case model.auth of
                Authenticated user ->
                    ( { model | auth = Authenticated { user | token = token } }, Cmd.none )

                Anonymous ->
                    ( model, Cmd.none )

        GotMe (Ok userId) ->
            ( { model | apiCall = Loaded userId }, Cmd.none )

        GotMe (Err _) ->
            ( { model | apiCall = Failed "could not reach the server" }, Cmd.none )


view : Model -> Browser.Document Msg
view model =
    { title = "felm-example"
    , body =
        [ case model.route of
            Home ->
                viewHome model

            Login ->
                viewLogin model.auth

            NotFound ->
                text "Not found"
        ]
    }


viewHome : Model -> Html Msg
viewHome model =
    div []
        [ h1 [] [ text "felm-example" ]
        , case model.auth of
            Authenticated { name } ->
                div []
                    [ p [] [ text ("Hello, " ++ name) ]
                    , viewApiCall model.apiCall
                    , button [ onClick LogoutClicked ] [ text "Log out" ]
                    ]

            Anonymous ->
                div []
                    [ p [] [ text "You are not logged in." ]
                    , button [ onClick LoginClicked ] [ text "Log in" ]
                    , p [] [ a [ href "/login" ] [ text "Go to login page" ] ]
                    ]
        ]


viewLogin : Auth -> Html Msg
viewLogin auth =
    case auth of
        Authenticated { name } ->
            div []
                [ h1 [] [ text "Log in" ]
                , p [] [ text ("Already logged in as " ++ name) ]
                , a [ href "/" ] [ text "Go home" ]
                ]

        Anonymous ->
            div []
                [ h1 [] [ text "Log in" ]
                , button [ onClick LoginClicked ] [ text "Log in with Keycloak" ]
                ]


viewApiCall : ApiCall -> Html Msg
viewApiCall apiCall =
    case apiCall of
        Idle ->
            text ""

        Loading ->
            p [] [ text "Checking in with the server..." ]

        Loaded userId ->
            p [] [ text ("Server says: hello, user " ++ userId) ]

        Failed message ->
            p [] [ text ("Server error: " ++ message) ]
