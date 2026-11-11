module Page.NotFound exposing (view)

import Html exposing (Html, text)
import Ui


view : { title : String, content : Html msg }
view =
    { title = "Not found"
    , content = Ui.pageTitle "Not found"
    }
