module Keycloak

open Browser
open Fable.Core.JS
open Fable.Core.JsInterop

let windowLocation = window.location.origin

type KeycloakConfig =
    {
        url: string
        realm: string
        clientId: string
    }

type TokenParsed = { given_name: string }

type KeycloakInitOptions =
    {
        onLoad: string
        silentCheckSsoRedirectUri: string
        enableLogging: bool
        responseMode: string
    }

type KeycloakLoginOptions = { redirectUri: string }

type Keycloak =
    abstract authenticated: bool
    abstract tokenParsed: TokenParsed
    abstract token: string
    abstract init: options: KeycloakInitOptions -> Promise<bool>
    abstract login: options: KeycloakLoginOptions -> Promise<unit>
    abstract logout: options: KeycloakLoginOptions -> Promise<unit>
    /// Refreshes the token if it expires within `minValidity` seconds.
    /// Resolves true if a new token was fetched, false if the current one is still valid.
    abstract updateToken: minValidity: int -> Promise<bool>

let keycloakInstance = importDefault<JsConstructor> "keycloak-js"

let create (config: KeycloakConfig) : Keycloak =
    unbox <| keycloakInstance.Create [| box config |]

let config: KeycloakConfig =
    {
        url = Env.VITE_AUTH_ORIGIN
        realm = "safe-todo"
        clientId = "felm-client"
    }

let keycloak = create config
