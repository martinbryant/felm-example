module Page.Home exposing (Model, Msg, init, toSession, update, view)

import Api
import Html exposing (Html, a, button, div, form, input, li, ol, p, text)
import Html.Attributes exposing (class, classList, disabled, placeholder, type_, value)
import Html.Events exposing (onInput, onSubmit)
import Json.Decode as Decode
import Route
import Session exposing (Session)
import Todo exposing (Todo)
import Ui


type alias Model =
    { session : Session
    , todos : Status (List Todo)
    , input : String
    , showDeleted : Bool
    }


type Status a
    = Loading
    | Loaded a


type Msg
    = GotTodos (Result Api.Error (List Todo))
    | InputChanged String
    | ToggleShowDeleted Bool
    | SubmitClicked
    | AddedTodo (Result Api.Error Todo)


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , todos = Loading
      , input = ""
      , showDeleted = False
      }
    , case Session.cred session of
        Just cred ->
            fetchTodos cred False

        Nothing ->
            Cmd.none
    )


{-| The server leaves deleted todos out unless asked.
-}
fetchTodos : Api.Cred -> Bool -> Cmd Msg
fetchTodos cred includeDeleted =
    Api.get cred
        ("/api/todo?includeDeleted=" ++ boolToString includeDeleted)
        (Decode.list Todo.decoder)
        GotTodos


boolToString : Bool -> String
boolToString bool =
    if bool then
        "true"

    else
        "false"


toSession : Model -> Session
toSession =
    .session


update : Msg -> Model -> ( Model, Cmd Msg, Maybe Api.Error )
update msg model =
    case msg of
        GotTodos (Ok todos) ->
            ( { model | todos = Loaded todos }, Cmd.none, Nothing )

        GotTodos (Err error) ->
            ( { model | todos = Loaded [] }, Cmd.none, Just error )

        InputChanged input ->
            ( { model | input = input }, Cmd.none, Nothing )

        ToggleShowDeleted show ->
            ( { model | showDeleted = show }
            , case Session.cred model.session of
                Just cred ->
                    fetchTodos cred show

                Nothing ->
                    Cmd.none
            , Nothing
            )

        SubmitClicked ->
            let
                description =
                    String.trim model.input
            in
            if String.isEmpty description then
                ( model, Cmd.none, Nothing )

            else
                case Session.cred model.session of
                    Just cred ->
                        let
                            body =
                                Todo.encodeNew description
                        in
                        ( { model | input = "" }
                        , Api.post cred "/api/todo" body Todo.decoder AddedTodo
                        , Nothing
                        )

                    Nothing ->
                        ( model, Cmd.none, Nothing )

        AddedTodo (Ok todo) ->
            ( { model | todos = mapLoaded (\todos -> todos ++ [ todo ]) model.todos }
            , Cmd.none
            , Nothing
            )

        AddedTodo (Err error) ->
            ( model, Cmd.none, Just error )


mapLoaded : (a -> a) -> Status a -> Status a
mapLoaded transform status =
    case status of
        Loading ->
            Loading

        Loaded a ->
            Loaded (transform a)


view : Model -> { title : String, content : Html Msg }
view model =
    { title = "Todos"
    , content =
        div [ class "mx-auto max-w-xl" ]
            [ Ui.pageTitle "todo-app"
            , Ui.box
                [ case Session.viewer model.session of
                    Nothing ->
                        p []
                            [ text "Please "
                            , a [ Route.href Route.Login, class "text-teal-600 underline" ] [ text "log in" ]
                            , text " to see your todos."
                            ]

                    Just _ ->
                        viewTodos model
                ]
            ]
    }


viewTodos : Model -> Html Msg
viewTodos model =
    let
        addDisabled =
            String.isEmpty (String.trim model.input)
    in
    div []
        [ case model.todos of
            Loading ->
                p [ class "text-gray-500" ] [ text "Loading..." ]

            Loaded todos ->
                let
                    items =
                        List.map viewTodo todos
                in
                ol [ class "mb-6 list-decimal space-y-1 pl-6" ] items
        , form [ class "flex gap-2", onSubmit SubmitClicked ]
            [ input
                [ type_ "text"
                , class "flex-1 rounded border border-gray-300 px-3 py-2 focus:border-teal-500 focus:outline-none"
                , placeholder "What needs to be done?"
                , value model.input
                , onInput InputChanged
                ]
                []
            , button
                [ type_ "submit"
                , Ui.primaryButton
                , disabled addDisabled
                ]
                [ text "Add" ]
            ]
        , Ui.toggle
            { id = "deleted-toggle"
            , text = "Show deleted?"
            , isOn = model.showDeleted
            , onToggle = ToggleShowDeleted
            }
        ]


viewTodo : Todo -> Html Msg
viewTodo todo =
    let
        deleted =
            Todo.isDeleted todo

        finished =
            Todo.isCompleted todo || deleted
    in
    li
        [ classList
            [ ( "line-through", finished )
            , ( "text-red-500", deleted )
            ]
        ]
        [ a [ Route.href (Route.Todo todo.id), class "hover:underline" ] [ text todo.description ] ]
