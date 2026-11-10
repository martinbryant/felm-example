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

/// Minimum remaining lifetime (seconds) a token must have to be handed to Elm.
/// Keycloak only contacts the server for a new one if it's closer to expiry than this.
let minTokenValiditySeconds = 30

/// Answers Elm's `requestToken` port with a token that is valid right now,
/// refreshing it first if needed. If the session can no longer be refreshed
/// (refresh token expired, logged out elsewhere) the user goes back through login.
let provideToken (app: ElmApp) () =
    (keycloak.updateToken minTokenValiditySeconds)
        .``then``(
            (fun _ -> sendPort app "gotToken" keycloak.token),
            (fun _ -> keycloak.login { redirectUri = windowLocation } |> ignore)
        )
    |> ignore

let onInitialized (authenticated: bool) =
    let flags: Flags =
        {
            authenticated = authenticated
            name =
                (if authenticated then
                     keycloak.tokenParsed.given_name
                 else
                     "")
        }

    let node = document.getElementById "app"
    let app = mount node flags

    subscribePort app "requestLogin" (fun () -> keycloak.login { redirectUri = windowLocation } |> ignore)
    subscribePort app "requestLogout" (fun () -> keycloak.logout { redirectUri = windowLocation } |> ignore)
    subscribePort app "requestToken" (provideToken app)

// Fable.Core.JS.Promise doesn't expose a `promise { }` computation expression,
// so the init callback is chained directly via `.then` (an F# keyword, hence
// the double-backtick escape) rather than using `let!`.
(keycloak.init initOptions).``then``(onInitialized, ignore) |> ignore
