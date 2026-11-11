module Page.Home exposing (Model, Msg, init, toSession, update, view)

import Api
import Html exposing (Html, a, button, div, form, input, li, ol, p, text)
import Html.Attributes exposing (class, classList, disabled, placeholder, type_, value)
import Html.Events exposing (onInput, onSubmit)
import Json.Decode as Decode
import Ports
import Route
import Session exposing (Session)
import Todo exposing (Todo)
import Ui


type alias Model =
    { session : Session
    , todos : Status (List Todo)
    , input : String
    , showDeleted : Bool
    , error : Maybe Api.Error
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
      , error = Nothing
      }
    , case Session.cred session of
        Just cred ->
            Api.get cred "/api/todo" (Decode.list Todo.decoder) GotTodos

        Nothing ->
            Cmd.none
    )


toSession : Model -> Session
toSession =
    .session


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotTodos (Ok todos) ->
            ( { model | todos = Loaded todos, error = Nothing }, Cmd.none )

        GotTodos (Err error) ->
            failed error { model | todos = Loaded [] }

        InputChanged input ->
            ( { model | input = input }, Cmd.none )

        ToggleShowDeleted show ->
            ( { model | showDeleted = show }, Cmd.none )

        SubmitClicked ->
            if String.isEmpty (String.trim model.input) then
                ( model, Cmd.none )

            else
                case Session.cred model.session of
                    Just cred ->
                        ( { model | input = "" }
                        , Api.post cred "/api/todo" (Todo.encodeNew (String.trim model.input)) Todo.decoder AddedTodo
                        )

                    Nothing ->
                        ( model, Cmd.none )

        AddedTodo (Ok todo) ->
            ( { model | todos = mapLoaded (\todos -> todos ++ [ todo ]) model.todos, error = Nothing }
            , Cmd.none
            )

        AddedTodo (Err error) ->
            failed error model


mapLoaded : (a -> a) -> Status a -> Status a
mapLoaded f status =
    case status of
        Loading ->
            Loading

        Loaded a ->
            Loaded (f a)


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
    div []
        [ case model.error of
            Just error ->
                Ui.errorMessage error

            Nothing ->
                text ""
        , case model.todos of
            Loading ->
                p [ class "text-gray-500" ] [ text "Loading..." ]

            Loaded todos ->
                ol [ class "mb-6 list-decimal space-y-1 pl-6" ]
                    (todos
                        |> List.filter (\todo -> model.showDeleted || not (Todo.isDeleted todo))
                        |> List.map viewTodo
                    )
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
                , disabled (String.isEmpty (String.trim model.input))
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
    li
        [ classList
            [ ( "line-through", Todo.isCompleted todo || Todo.isDeleted todo )
            , ( "text-red-500", Todo.isDeleted todo )
            ]
        ]
        [ a [ Route.href (Route.Todo todo.id), class "hover:underline" ] [ text todo.description ] ]
