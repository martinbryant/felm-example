module Page.NotFound exposing (view)

import Html exposing (Html, h1, text)


view : { title : String, content : Html msg }
view =
    { title = "Not found"
    , content = h1 [] [ text "Not found" ]
    }
