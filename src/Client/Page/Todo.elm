module Page.Todo exposing (Model, Msg, init, toSession, update, view)

import Api
import Format
import Html exposing (Html, a, button, div, h1, h2, li, ol, p, span, text)
import Html.Attributes exposing (class, classList, disabled)
import Html.Events exposing (onClick)
import Route
import Session exposing (Session)
import Time
import Todo exposing (HistoryItem, Todo)
import Ui


type alias Model =
    { session : Session
    , id : String
    , todo : Status Todo
    , history : List HistoryItem
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
    ( { session = session, id = id, todo = Loading, history = [], confirmingRemove = False }
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


update : Msg -> Model -> ( Model, Cmd Msg, Maybe Api.Error )
update msg model =
    case msg of
        GotTodo (Ok todo) ->
            ( { model | todo = Loaded todo }, Cmd.none, Nothing )

        GotTodo (Err error) ->
            ( { model | todo = Missing }, Cmd.none, Just error )

        GotHistory (Ok history) ->
            ( { model | history = history }, Cmd.none, Nothing )

        GotHistory (Err error) ->
            ( model, Cmd.none, Just error )

        CompleteClicked ->
            let
                path =
                    todoPath model.id ++ "/complete"
            in
            ( model
            , withCred model (\cred -> Api.postEmpty cred path Todo.decoder Completed)
            , Nothing
            )

        Completed (Ok todo) ->
            ( { model | todo = Loaded todo }
            , withCred model (\cred -> fetchHistory cred model.id)
            , Nothing
            )

        Completed (Err error) ->
            ( model, Cmd.none, Just error )

        RemoveClicked ->
            ( { model | confirmingRemove = True }, Cmd.none, Nothing )

        CancelRemoveClicked ->
            ( { model | confirmingRemove = False }, Cmd.none, Nothing )

        ConfirmRemoveClicked ->
            let
                path =
                    todoPath model.id
            in
            ( { model | confirmingRemove = False }
            , withCred model (\cred -> Api.delete cred path Removed)
            , Nothing
            )

        Removed (Ok ()) ->
            let
                navKey =
                    Session.navKey model.session
            in
            ( model
            , Route.pushUrl navKey Route.Home
            , Nothing
            )

        Removed (Err error) ->
            ( model, Cmd.none, Just error )


{-| Runs an API call if there is a credential; a guest has nothing to call with.
-}
withCred : Model -> (Api.Cred -> Cmd Msg) -> Cmd Msg
withCred model call =
    case Session.cred model.session of
        Just cred ->
            call cred

        Nothing ->
            Cmd.none


view : Time.Zone -> Model -> { title : String, content : Html Msg }
view zone model =
    { title = "Todo"
    , content =
        div [ class "mx-auto max-w-xl" ]
            [ Ui.pageTitle "todo-app"
            , Ui.box
                [ case model.todo of
                    Loading ->
                        p [ class "text-gray-500" ] [ text "Loading..." ]

                    Missing ->
                        p [] [ text "That todo could not be found." ]

                    Loaded todo ->
                        viewTodo zone todo model.history
                , p [ class "mt-6" ]
                    [ a [ Route.href Route.Home, class "text-teal-600 hover:underline" ] [ text "< All todos" ] ]
                ]
            , if model.confirmingRemove then
                viewConfirmation

              else
                text ""
            ]
    }


viewTodo : Time.Zone -> Todo -> List HistoryItem -> Html Msg
viewTodo zone todo history =
    let
        finished =
            Todo.isCompleted todo || Todo.isDeleted todo

        deleted =
            Todo.isDeleted todo

        created =
            "Created on " ++ Format.dateTime zone todo.created

        historyItems =
            List.map (viewHistoryItem zone) history
    in
    div []
        [ h1
            [ classList [ ( "text-2xl font-semibold", True ), ( "line-through", finished ) ] ]
            [ text todo.description ]
        , p [ class "mb-4 text-sm text-gray-500" ] [ text created ]
        , div [ class "flex gap-2" ]
            [ button [ Ui.successButton, disabled finished, onClick CompleteClicked ] [ text "Complete" ]
            , button [ Ui.dangerButton, disabled deleted, onClick RemoveClicked ] [ text "Delete" ]
            ]
        , h2 [ class "mt-8 mb-4 inline-block rounded bg-teal-500 px-3 py-1 text-lg text-white" ] [ text "History" ]
        , ol [ class "ml-4 border-l-2 border-gray-200" ] historyItems
        ]


viewHistoryItem : Time.Zone -> HistoryItem -> Html msg
viewHistoryItem zone item =
    let
        ( colour, icon ) =
            case item.event of
                Todo.Created _ ->
                    ( "bg-sky-500", "+" )

                Todo.Completed ->
                    ( "bg-teal-500", "✓" )

                Todo.Deleted ->
                    ( "bg-red-500", "✕" )

        name =
            Todo.eventName item.event

        date =
            Format.dateTime zone item.at

        iconClass =
            "absolute -left-4 top-0 flex h-8 w-8 items-center justify-center rounded-full text-white " ++ colour
    in
    li [ class "relative pb-6 pl-8" ]
        [ span
            [ class iconClass ]
            [ text icon ]
        , p [ class "font-medium" ] [ text name ]
        , p [ class "text-sm text-gray-500" ] [ text date ]
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
