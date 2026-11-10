module Page.Todo exposing (Model, Msg, init, toSession, update, view)

import Api
import Html exposing (Html, a, button, div, h1, h2, li, p, text, ul)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Ports
import Route
import Session exposing (Session)
import Todo exposing (HistoryItem, Todo)


type alias Model =
    { session : Session
    , id : String
    , todo : Status Todo
    , history : List HistoryItem
    , error : Maybe Api.Error
    }


type Status a
    = Loading
    | Loaded a
    | Missing


type Msg
    = GotTodo (Result Api.Error Todo)
    | GotHistory (Result Api.Error (List HistoryItem))
    | CompleteClicked
    | RemoveClicked
    | Completed (Result Api.Error Todo)
    | Removed (Result Api.Error ())


init : Session -> String -> ( Model, Cmd Msg )
init session id =
    ( { session = session, id = id, todo = Loading, history = [], error = Nothing }
    , case Session.cred session of
        Just cred ->
            Cmd.batch [ fetchTodo cred id, fetchHistory cred id ]

        Nothing ->
            Cmd.none
    )


todoPath : String -> String
todoPath id =
    "/api/todo/" ++ id


fetchTodo : Api.Cred -> String -> Cmd Msg
fetchTodo cred id =
    Api.get cred (todoPath id) Todo.decoder GotTodo


fetchHistory : Api.Cred -> String -> Cmd Msg
fetchHistory cred id =
    Api.get cred (todoPath id ++ "/history") Todo.historyDecoder GotHistory


toSession : Model -> Session
toSession =
    .session


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotTodo (Ok todo) ->
            ( { model | todo = Loaded todo }, Cmd.none )

        GotTodo (Err Api.NotFound) ->
            ( { model | todo = Missing }, Cmd.none )

        GotTodo (Err error) ->
            failed error { model | todo = Missing }

        GotHistory (Ok history) ->
            ( { model | history = history }, Cmd.none )

        GotHistory (Err error) ->
            failed error model

        CompleteClicked ->
            ( model
            , withCred model (\cred -> Api.postEmpty cred (todoPath model.id ++ "/complete") Todo.decoder Completed)
            )

        Completed (Ok todo) ->
            ( { model | todo = Loaded todo, error = Nothing }
            , withCred model (\cred -> fetchHistory cred model.id)
            )

        Completed (Err error) ->
            failed error model

        RemoveClicked ->
            ( model
            , withCred model (\cred -> Api.delete cred (todoPath model.id) Removed)
            )

        Removed (Ok ()) ->
            ( model
            , Route.pushUrl (Session.navKey model.session) Route.Home
            )

        Removed (Err error) ->
            failed error model


{-| Runs an API call if there is a credential; a guest has nothing to call with.
-}
withCred : Model -> (Api.Cred -> Cmd Msg) -> Cmd Msg
withCred model call =
    case Session.cred model.session of
        Just cred ->
            call cred

        Nothing ->
            Cmd.none


{-| An expired access token comes back as 401. The Keycloak session outlives it,
so logging in again is a quick redirect that returns with a fresh token.
-}
failed : Api.Error -> Model -> ( Model, Cmd Msg )
failed error model =
    case error of
        Api.Unauthorized ->
            ( model, Ports.requestLogin () )

        _ ->
            ( { model | error = Just error }, Cmd.none )


view : Model -> { title : String, content : Html Msg }
view model =
    { title = "Todo"
    , content =
        div []
            [ p [] [ a [ Route.href Route.Home ] [ text "< All todos" ] ]
            , case model.error of
                Just error ->
                    p [ style "color" "crimson" ] [ text (Api.errorMessage error) ]

                Nothing ->
                    text ""
            , case model.todo of
                Loading ->
                    p [] [ text "Loading..." ]

                Missing ->
                    p [] [ text "That todo could not be found." ]

                Loaded todo ->
                    viewTodo todo model.history
            ]
    }


viewTodo : Todo -> List HistoryItem -> Html Msg
viewTodo todo history =
    div []
        [ h1 [] [ text todo.description ]
        , p [] [ text ("Created " ++ String.left 10 todo.created) ]
        , div []
            [ button [ onClick CompleteClicked ] [ text "Complete" ]
            , button [ onClick RemoveClicked ] [ text "Delete" ]
            ]
        , h2 [] [ text "History" ]
        , ul []
            (List.map
                (\item -> li [] [ text (String.left 19 item.at ++ " - " ++ Todo.eventLabel item.event) ])
                history
            )
        ]
