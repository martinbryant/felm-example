module Ui exposing (box, dangerButton, lightButton, pageTitle, primaryButton, successButton, tabs)

{-| Shared Tailwind building blocks, so the pages agree on what a box, a button
or a tab bar looks like.
-}

import Html exposing (Attribute, Html, button, div, h1, text)
import Html.Attributes exposing (class, type_)
import Html.Events exposing (onClick)


pageTitle : String -> Html msg
pageTitle title =
    h1 [ class "mb-6 text-center text-4xl font-semibold text-white" ] [ text title ]


box : List (Html msg) -> Html msg
box children =
    div [ class "rounded-lg bg-white p-6 shadow-lg" ] children


buttonBase : String
buttonBase =
    "rounded px-4 py-2 font-medium text-white transition disabled:cursor-not-allowed disabled:opacity-50 "


primaryButton : Attribute msg
primaryButton =
    class (buttonBase ++ "bg-teal-500 hover:bg-teal-600")


successButton : Attribute msg
successButton =
    class (buttonBase ++ "bg-green-500 hover:bg-green-600")


dangerButton : Attribute msg
dangerButton =
    class (buttonBase ++ "bg-red-500 hover:bg-red-600")


lightButton : Attribute msg
lightButton =
    class "rounded bg-gray-100 px-4 py-2 font-medium text-gray-700 transition hover:bg-gray-200"


{-| A row of joined buttons where one is active, like Bulma's `buttons has-addons`.
-}
tabs : List { label : String, isActive : Bool, onClick : msg } -> Html msg
tabs options =
    div [ class "mb-6 inline-flex overflow-hidden rounded border border-gray-300" ]
        (List.map tab options)


tab : { label : String, isActive : Bool, onClick : msg } -> Html msg
tab option =
    let
        colours =
            if option.isActive then
                "bg-teal-500 text-white"

            else
                "bg-white text-gray-700 hover:bg-gray-100"
    in
    button
        [ type_ "button"
        , class ("border-r border-gray-300 px-4 py-2 font-medium transition last:border-r-0 " ++ colours)
        , onClick option.onClick
        ]
        [ text option.label ]
