module Page exposing (Page(..), view)

{-| The frame around every page: header and navigation.
-}

import Browser exposing (Document)
import Html exposing (Html, a, div, header, nav, span, text)
import Html.Attributes exposing (class)
import Route
import Session exposing (Viewer)


type Page
    = Other
    | Home
    | Login
    | Todo


view : Maybe Viewer -> Page -> { title : String, content : Html msg } -> Document msg
view maybeViewer _ { title, content } =
    { title = title ++ " - felm-example"
    , body = [ viewHeader maybeViewer, div [ class "page" ] [ content ] ]
    }


viewHeader : Maybe Viewer -> Html msg
viewHeader maybeViewer =
    header []
        [ nav []
            [ a [ Route.href Route.Home ] [ text "felm-example" ]
            , case maybeViewer of
                Just viewer ->
                    span []
                        [ text ("Hello, " ++ viewer.name ++ " ")
                        , a [ Route.href Route.Logout ] [ text "Log out" ]
                        ]

                Nothing ->
                    a [ Route.href Route.Login ] [ text "Log in" ]
            ]
        ]
