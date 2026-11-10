port module Ports exposing (requestLogin, requestLogout)

{-| Everything that crosses into JavaScript (Keycloak).
-}


port requestLogin : () -> Cmd msg


port requestLogout : () -> Cmd msg
