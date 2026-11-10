module Route exposing (Route(..), fromUrl, href, pushUrl)

import Browser.Navigation as Nav
import Html exposing (Attribute)
import Html.Attributes as Attr
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser, oneOf, s, top)


type Route
    = Home
    | Login
    | Logout
    | Todo String


parser : Parser (Route -> a) a
parser =
    oneOf
        [ Parser.map Home top
        , Parser.map Login (s "login")
        , Parser.map Logout (s "logout")
        , Parser.map Todo (s "todo" </> Parser.string)
        ]


href : Route -> Attribute msg
href route =
    Attr.href (toString route)


pushUrl : Nav.Key -> Route -> Cmd msg
pushUrl navKey route =
    Nav.pushUrl navKey (toString route)


fromUrl : Url -> Maybe Route
fromUrl url =
    Parser.parse parser url


toString : Route -> String
toString route =
    case route of
        Home ->
            "/"

        Login ->
            "/login"

        Logout ->
            "/logout"

        Todo id ->
            "/todo/" ++ id
