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
    | Authenticated { name : String }


type ApiCall
    = Idle
    | Loading
    | Loaded String
    | Failed String


type alias Flags =
    { authenticated : Bool
    , name : String
    }


type alias Model =
    { key : Nav.Key
    , route : Route
    , auth : Auth
    , apiCall : ApiCall
    , pendingCalls : List (String -> Cmd Msg)
    }


type Msg
    = UrlChanged Url.Url
    | LinkClicked Browser.UrlRequest
    | LoginClicked
    | LogoutClicked
    | GotToken String
    | GotMe (Result Http.Error String)


port requestLogin : () -> Cmd msg


port requestLogout : () -> Cmd msg


port requestToken : () -> Cmd msg


port gotToken : (String -> msg) -> Sub msg


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> gotToken GotToken
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
                Authenticated { name = flags.name }

            else
                Anonymous

        model =
            { key = key, route = toRoute url, auth = auth, apiCall = Idle, pendingCalls = [] }
    in
    case auth of
        Authenticated _ ->
            withToken fetchMe { model | apiCall = Loading }

        Anonymous ->
            ( model, Cmd.none )


{-| Runs an API call once JS has handed back a token that is valid right now.
JS refreshes the token first if it is about to expire, so no token is ever
kept in the model.
-}
withToken : (String -> Cmd Msg) -> Model -> ( Model, Cmd Msg )
withToken call model =
    ( { model | pendingCalls = call :: model.pendingCalls }, requestToken () )


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

        GotToken token ->
            ( { model | pendingCalls = [] }
            , Cmd.batch (List.map (\call -> call token) model.pendingCalls)
            )

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
