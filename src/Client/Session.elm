module Session exposing (Session, Viewer, cred, fromViewer, navKey, viewer)

import Api exposing (Cred)
import Browser.Navigation as Nav


type alias Viewer =
    { name : String
    , cred : Cred
    }


type Session
    = Guest Nav.Key
    | LoggedIn Nav.Key Viewer


fromViewer : Nav.Key -> Maybe Viewer -> Session
fromViewer key maybeViewer =
    case maybeViewer of
        Just v ->
            LoggedIn key v

        Nothing ->
            Guest key


navKey : Session -> Nav.Key
navKey session =
    case session of
        Guest key ->
            key

        LoggedIn key _ ->
            key


viewer : Session -> Maybe Viewer
viewer session =
    case session of
        Guest _ ->
            Nothing

        LoggedIn _ v ->
            Just v


cred : Session -> Maybe Cred
cred session =
    Maybe.map .cred (viewer session)
