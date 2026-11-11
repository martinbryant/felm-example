module Ui exposing (box, dangerButton, lightButton, pageTitle, primaryButton, successButton, toggle)

{-| Shared Tailwind building blocks, so the pages agree on what a box, a button
or a switch looks like.
-}

import Html exposing (Attribute, Html, div, h1, input, label, span, text)
import Html.Attributes exposing (checked, class, for, id, type_)
import Html.Events exposing (onCheck)


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


{-| A rounded on/off switch built on a real checkbox.
-}
toggle : { id : String, text : String, isOn : Bool, onToggle : Bool -> msg } -> Html msg
toggle config =
    label [ for config.id, class "mt-6 flex cursor-pointer items-center gap-3 text-gray-700" ]
        [ input
            [ type_ "checkbox"
            , id config.id
            , class "peer sr-only"
            , checked config.isOn
            , onCheck config.onToggle
            ]
            []
        , span
            [ class "relative h-6 w-11 rounded-full bg-gray-300 transition peer-checked:bg-green-500 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white after:transition peer-checked:after:translate-x-5" ]
            []
        , text config.text
        ]
