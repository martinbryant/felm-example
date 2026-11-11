module Toast exposing (Toast, config, view)

{-| Error toasts shown top-centre, like Toastr's `TopCenter` in the SAFE
example. Built on `pablen/toasty`, which leaves all markup and styling to us.
-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class, style)
import Toasty


type alias Toast =
    String


config : Toasty.Config msg
config =
    Toasty.config
        |> Toasty.delay 5000
        |> Toasty.containerAttrs
            [ class "fixed top-4 left-1/2 z-50 m-0 w-full max-w-sm -translate-x-1/2 list-none space-y-2 px-4"
            , style "pointer-events" "none"
            ]
        |> Toasty.itemAttrs [ class "list-none" ]
        |> Toasty.transitionInAttrs [ class "animate-[toast-in_0.3s_ease-out]" ]
        |> Toasty.transitionOutAttrs [ class "opacity-0 transition-opacity duration-500" ]
        |> Toasty.transitionOutDuration 700


view : Toast -> Html msg
view message =
    div
        [ class "pointer-events-auto rounded bg-red-600 px-4 py-3 text-white shadow-lg"
        , style "pointer-events" "auto"
        ]
        [ text message ]
