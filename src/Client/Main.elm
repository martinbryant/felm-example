module Main exposing (main)

import Api
import Browser exposing (Document)
import Browser.Navigation as Nav
import Html
import Page exposing (Page)
import Page.Home as Home
import Page.Login as Login
import Page.NotFound as NotFound
import Page.Todo as Todo
import Ports
import Route exposing (Route)
import Session exposing (Session)
import Toast exposing (Toast)
import Toasty
import Task
import Time
import Url exposing (Url)


type alias Flags =
    { authenticated : Bool
    , name : String
    , token : String
    }



-- MODEL


type alias Model =
    { screen : Screen
    , zone : Time.Zone
    , toasties : Toasty.Stack Toast
    }


type Screen
    = Redirect Session
    | NotFound Session
    | Home Home.Model
    | Login Login.Model
    | Todo Todo.Model


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url navKey =
    let
        viewer =
            if flags.authenticated then
                Just
                    { name = flags.name
                    , cred = Api.credFromToken flags.token
                    }

            else
                Nothing
    in
    changeRouteTo (Route.fromUrl url)
        { screen = Redirect (Session.fromViewer navKey viewer)
        , zone = Time.utc
        , toasties = Toasty.initialState
        }
        |> Tuple.mapSecond (\cmd -> Cmd.batch [ cmd, Task.perform GotZone Time.here ])



-- VIEW


view : Model -> Document Msg
view model =
    let
        { title, body } =
            viewScreen model.zone model.screen
    in
    { title = title
    , body = body ++ [ Toasty.view Toast.config Toast.view ToastyMsg model.toasties ]
    }


viewScreen : Time.Zone -> Screen -> Document Msg
viewScreen zone screen =
    let
        viewer =
            Session.viewer (toSession screen)

        viewPage page toMsg config =
            let
                { title, body } =
                    Page.view viewer page config
            in
            { title = title
            , body = List.map (Html.map toMsg) body
            }
    in
    case screen of
        Redirect _ ->
            Page.view viewer Page.Other { title = "", content = Html.text "" }

        NotFound _ ->
            Page.view viewer Page.Other NotFound.view

        Home home ->
            viewPage Page.Home GotHomeMsg (Home.view home)

        Login login ->
            viewPage Page.Login GotLoginMsg (Login.view login)

        Todo todo ->
            viewPage Page.Todo GotTodoMsg (Todo.view zone todo)



-- UPDATE


type Msg
    = ChangedUrl Url
    | ClickedLink Browser.UrlRequest
    | GotHomeMsg Home.Msg
    | GotLoginMsg Login.Msg
    | GotTodoMsg Todo.Msg
    | ToastyMsg (Toasty.Msg Toast)
    | GotZone Time.Zone


toSession : Screen -> Session
toSession page =
    case page of
        Redirect session ->
            session

        NotFound session ->
            session

        Home home ->
            Home.toSession home

        Login login ->
            Login.toSession login

        Todo todo ->
            Todo.toSession todo


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
    let
        session =
            toSession model.screen
    in
    case maybeRoute of
        Nothing ->
            ( { model | screen = NotFound session }, Cmd.none )

        Just Route.Home ->
            Home.init session
                |> updateWith Home GotHomeMsg model

        Just Route.Login ->
            Login.init session
                |> updateWith Login GotLoginMsg model

        Just Route.Logout ->
            ( model, Ports.requestLogout () )

        Just (Route.Todo id) ->
            Todo.init session id
                |> updateWith Todo GotTodoMsg model


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.screen ) of
        ( ClickedLink urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    ( model
                    , Nav.pushUrl (Session.navKey (toSession model.screen)) (Url.toString url)
                    )

                Browser.External href ->
                    ( model, Nav.load href )

        ( ChangedUrl url, _ ) ->
            changeRouteTo (Route.fromUrl url) model

        ( GotZone zone, _ ) ->
            ( { model | zone = zone }, Cmd.none )

        ( ToastyMsg subMsg, _ ) ->
            Toasty.update Toast.config ToastyMsg subMsg model

        ( GotHomeMsg subMsg, Home home ) ->
            Home.update subMsg home
                |> updateWithError Home GotHomeMsg model

        ( GotLoginMsg subMsg, Login login ) ->
            Login.update subMsg login
                |> updateWith Login GotLoginMsg model

        ( GotTodoMsg subMsg, Todo todo ) ->
            Todo.update subMsg todo
                |> updateWithError Todo GotTodoMsg model

        ( _, _ ) ->
            -- Disregard messages that arrived for the wrong page, e.g. a late
            -- HTTP response after navigating away.
            ( model, Cmd.none )


updateWith : (subModel -> Screen) -> (subMsg -> Msg) -> Model -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toScreen toMsg model ( subModel, subCmd ) =
    ( { model | screen = toScreen subModel }
    , Cmd.map toMsg subCmd
    )


{-| Like `updateWith`, for pages that report API failures to be shown as toasts.
-}
updateWithError : (subModel -> Screen) -> (subMsg -> Msg) -> Model -> ( subModel, Cmd subMsg, Maybe Api.Error ) -> ( Model, Cmd Msg )
updateWithError toScreen toMsg model ( subModel, subCmd, maybeError ) =
    let
        ( next, cmd ) =
            updateWith toScreen toMsg model ( subModel, subCmd )
    in
    case maybeError of
        Nothing ->
            ( next, cmd )

        Just error ->
            handleError error ( next, cmd )


{-| The same reactions as the SAFE example: a toast for every failure, plus a
fresh login on 401 (the Keycloak session outlives the access token, so it is a
quick redirect) and back to the list on 404.
-}
handleError : Api.Error -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
handleError error ( model, cmd ) =
    let
        navKey =
            Session.navKey (toSession model.screen)

        ( message, extra ) =
            case error of
                Api.Unauthorized ->
                    ( "You must be logged in to do this", Ports.requestLogin () )

                Api.Forbidden ->
                    ( "You don't have permission to do this", Cmd.none )

                Api.NotFound ->
                    ( "That todo doesn't exist", Route.pushUrl navKey Route.Home )

                Api.Other _ ->
                    ( "An unexpected error has occured. Please try again", Cmd.none )
    in
    ( model, Cmd.batch [ cmd, extra ] )
        |> Toasty.addToast Toast.config ToastyMsg message



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- MAIN


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = ChangedUrl
        , onUrlRequest = ClickedLink
        }
