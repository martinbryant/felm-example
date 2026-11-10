module Page.Home exposing (Model, Msg, init, toSession, update, view)

import Api
import Html exposing (Html, a, button, div, form, h1, input, label, li, ol, p, text)
import Html.Attributes exposing (checked, placeholder, style, type_, value)
import Html.Events exposing (onCheck, onInput, onSubmit)
import Json.Decode as Decode
import Ports
import Route
import Session exposing (Session)
import Todo exposing (Todo)


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
        div []
            [ h1 [] [ text "Todos" ]
            , case Session.viewer model.session of
                Nothing ->
                    p [] [ text "You are not logged in." ]

                Just _ ->
                    viewTodos model
            ]
    }


viewTodos : Model -> Html Msg
viewTodos model =
    div []
        [ viewError model.error
        , case model.todos of
            Loading ->
                p [] [ text "Loading..." ]

            Loaded todos ->
                ol []
                    (todos
                        |> List.filter (\todo -> model.showDeleted || not (Todo.isDeleted todo))
                        |> List.map viewTodo
                    )
        , form [ onSubmit SubmitClicked ]
            [ input [ type_ "text", placeholder "What needs doing?", value model.input, onInput InputChanged ] []
            , button [ type_ "submit" ] [ text "Add" ]
            ]
        , label []
            [ input [ type_ "checkbox", checked model.showDeleted, onCheck ToggleShowDeleted ] []
            , text " Show deleted"
            ]
        ]


viewTodo : Todo -> Html Msg
viewTodo todo =
    li
        [ if Todo.isCompleted todo || Todo.isDeleted todo then
            style "text-decoration" "line-through"

          else
            style "text-decoration" "none"
        ]
        [ a [ Route.href (Route.Todo todo.id) ] [ text todo.description ] ]


viewError : Maybe Api.Error -> Html msg
viewError error =
    case error of
        Just e ->
            p [ style "color" "crimson" ] [ text (Api.errorMessage e) ]

        Nothing ->
            text ""
