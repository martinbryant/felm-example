module Page exposing (Page(..), view)

{-| The frame around every page: a full-height teal backdrop, a transparent
navigation bar with the logo and a "Hi <name>" menu, and the page content.
-}

import Browser exposing (Document)
import Html exposing (Html, a, div, header, img, main_, span, text)
import Html.Attributes exposing (alt, class, src)
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
    , body =
        [ div [ class "min-h-screen bg-gradient-to-br from-teal-400 to-teal-700 text-gray-800" ]
            [ viewHeader maybeViewer
            , main_ [ class "px-4 py-10" ] [ content ]
            ]
        ]
    }


viewHeader : Maybe Viewer -> Html msg
viewHeader maybeViewer =
    header [ class "flex items-center justify-between px-10 py-4" ]
        [ a [ Route.href Route.Home ] [ img [ src "/favicon.png", alt "Logo", class "h-8" ] [] ]
        , viewMenu maybeViewer
        ]


{-| Opens on hover, as the navbar dropdown in the SAFE example does.
-}
viewMenu : Maybe Viewer -> Html msg
viewMenu maybeViewer =
    let
        ( greeting, action ) =
            case maybeViewer of
                Just viewer ->
                    ( viewer.name, a [ Route.href Route.Logout, itemClass ] [ text "Log out" ] )

                Nothing ->
                    ( "guest", a [ Route.href Route.Login, itemClass ] [ text "Log in" ] )
    in
    div [ class "group relative" ]
        [ span [ class "cursor-pointer font-medium text-white" ] [ text ("Hi " ++ greeting) ]
        , div [ class "absolute right-0 z-10 hidden pt-2 group-hover:block" ] [ action ]
        ]


itemClass : Html.Attribute msg
itemClass =
    class "block whitespace-nowrap rounded bg-white px-4 py-2 text-gray-700 shadow hover:bg-gray-100"
