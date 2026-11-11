module Page.Todo exposing (Model, Msg, init, toSession, update, view)

import Api
import Html exposing (Html, a, button, div, h1, h2, li, ol, p, span, text)
import Html.Attributes exposing (class, classList, disabled)
import Html.Events exposing (onClick)
import Ports
import Route
import Session exposing (Session)
import Todo exposing (HistoryItem, Todo)
import Ui


type alias Model =
    { session : Session
    , id : String
    , todo : Status Todo
    , history : List HistoryItem
    , error : Maybe Api.Error
    , confirmingRemove : Bool
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
    | CancelRemoveClicked
    | ConfirmRemoveClicked
    | Completed (Result Api.Error Todo)
    | Removed (Result Api.Error ())


init : Session -> String -> ( Model, Cmd Msg )
init session id =
    ( { session = session, id = id, todo = Loading, history = [], error = Nothing, confirmingRemove = False }
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
            ( { model | confirmingRemove = True }, Cmd.none )

        CancelRemoveClicked ->
            ( { model | confirmingRemove = False }, Cmd.none )

        ConfirmRemoveClicked ->
            ( { model | confirmingRemove = False }
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
        div [ class "mx-auto max-w-xl" ]
            [ Ui.pageTitle "todo-app"
            , Ui.box
                [ case model.error of
                    Just error ->
                        Ui.errorMessage error

                    Nothing ->
                        text ""
                , case model.todo of
                    Loading ->
                        p [ class "text-gray-500" ] [ text "Loading..." ]

                    Missing ->
                        p [] [ text "That todo could not be found." ]

                    Loaded todo ->
                        viewTodo todo model.history
                , p [ class "mt-6" ]
                    [ a [ Route.href Route.Home, class "text-teal-600 hover:underline" ] [ text "< All todos" ] ]
                ]
            , if model.confirmingRemove then
                viewConfirmation

              else
                text ""
            ]
    }


viewTodo : Todo -> List HistoryItem -> Html Msg
viewTodo todo history =
    let
        finished =
            Todo.isCompleted todo || Todo.isDeleted todo
    in
    div []
        [ h1
            [ classList [ ( "text-2xl font-semibold", True ), ( "line-through", finished ) ] ]
            [ text todo.description ]
        , p [ class "mb-4 text-sm text-gray-500" ] [ text ("Created " ++ Todo.shortDate todo.created) ]
        , div [ class "flex gap-2" ]
            [ button [ Ui.successButton, disabled finished, onClick CompleteClicked ] [ text "Complete" ]
            , button [ Ui.dangerButton, disabled (Todo.isDeleted todo), onClick RemoveClicked ] [ text "Delete" ]
            ]
        , h2 [ class "mt-8 mb-4 inline-block rounded bg-teal-500 px-3 py-1 text-lg text-white" ] [ text "History" ]
        , ol [ class "ml-4 border-l-2 border-gray-200" ] (List.map viewHistoryItem history)
        ]


viewHistoryItem : HistoryItem -> Html msg
viewHistoryItem item =
    let
        ( colour, icon ) =
            case item.event of
                Todo.Created _ ->
                    ( "bg-sky-500", "+" )

                Todo.Completed ->
                    ( "bg-teal-500", "✓" )

                Todo.Deleted ->
                    ( "bg-red-500", "✕" )
    in
    li [ class "relative pb-6 pl-8" ]
        [ span
            [ class ("absolute -left-4 top-0 flex h-8 w-8 items-center justify-center rounded-full text-white " ++ colour) ]
            [ text icon ]
        , p [ class "font-medium" ] [ text (Todo.eventName item.event) ]
        , p [ class "text-sm text-gray-500" ] [ text (Todo.shortDate item.at) ]
        ]


viewConfirmation : Html Msg
viewConfirmation =
    div [ class "fixed inset-0 z-20 flex items-center justify-center bg-black/50 px-4" ]
        [ Ui.box
            [ p [ class "mb-4 text-lg" ] [ text "Are you sure you want to remove this?" ]
            , div [ class "flex gap-2" ]
                [ button [ Ui.dangerButton, onClick ConfirmRemoveClicked ] [ text "Confirm" ]
                , button [ Ui.lightButton, onClick CancelRemoveClicked ] [ text "Cancel" ]
                ]
            ]
        ]
