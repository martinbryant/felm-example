module Main

open Browser
open Keycloak
open Interop

let initOptions: KeycloakInitOptions =
    {
        onLoad = "check-sso"
        silentCheckSsoRedirectUri = $"{windowLocation}/silent-check-sso.html"
        enableLogging = true
        responseMode = "query"
    }

let onInitialized (authenticated: bool) =
    let flags: Flags =
        {
            authenticated = authenticated
            name =
                (if authenticated then
                     keycloak.tokenParsed.given_name
                 else
                     "")
            token = (if authenticated then keycloak.token else "")
        }

    let node = document.getElementById "app"
    let app = mount node flags

    subscribePort app "requestLogin" (fun () -> keycloak.login { redirectUri = windowLocation } |> ignore)
    subscribePort app "requestLogout" (fun () -> keycloak.logout { redirectUri = windowLocation } |> ignore)

// Fable.Core.JS.Promise doesn't expose a `promise { }` computation expression,
// so the init callback is chained directly via `.then` (an F# keyword, hence
// the double-backtick escape) rather than using `let!`.
(keycloak.init initOptions).``then``(onInitialized, ignore) |> ignore
