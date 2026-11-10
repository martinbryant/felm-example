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

/// How often to check the token, and how close to expiry (in seconds) it must be
/// before Keycloak is asked for a new one.
let refreshCheckMs = 30_000
let refreshMinValiditySeconds = 60

/// Keeps the access token fresh and pushes each new one into Elm. If the
/// session can no longer be refreshed (e.g. the refresh token expired or the
/// user was logged out elsewhere), sends the user back through login.
let startTokenRefresh (app: ElmApp) =
    let check () =
        (keycloak.updateToken refreshMinValiditySeconds)
            .``then``(
                (fun refreshed ->
                    if refreshed then
                        sendPort app "tokenRefreshed" keycloak.token),
                (fun _ -> keycloak.login { redirectUri = windowLocation } |> ignore)
            )
        |> ignore

    Fable.Core.JS.setInterval check refreshCheckMs |> ignore

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

    if authenticated then
        startTokenRefresh app

// Fable.Core.JS.Promise doesn't expose a `promise { }` computation expression,
// so the init callback is chained directly via `.then` (an F# keyword, hence
// the double-backtick escape) rather than using `let!`.
(keycloak.init initOptions).``then``(onInitialized, ignore) |> ignore
