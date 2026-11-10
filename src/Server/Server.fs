module Server

open System.Security.Claims
open Microsoft.AspNetCore.Authentication.JwtBearer
open Microsoft.AspNetCore.Builder
open Microsoft.AspNetCore.Http
open Microsoft.Extensions.Configuration
open Microsoft.Extensions.DependencyInjection
open Microsoft.IdentityModel.Tokens
open Saturn
open Giraffe

type MeResponse = { userId: string }

let onlyLoggedIn =
    pipeline { requires_authentication (Auth.challenge JwtBearerDefaults.AuthenticationScheme) }

let meHandler: HttpHandler =
    fun next ctx ->
        let userId = ctx.User.FindFirst(ClaimTypes.NameIdentifier).Value
        json { userId = userId } next ctx

let apiRouter =
    router {
        pipe_through onlyLoggedIn
        get "/me" meHandler
    }

// In development Vite (:8080) serves the client and proxies "/api/*" here, so only
// the API router is ever hit. In production this server also serves the built
// client (see `use_static` below): anything that isn't a static file or an API
// route falls through to index.html so Elm's path-based routing (e.g. a refresh
// on "/login") works. Unknown "/api/*" paths 404 instead of returning HTML.
let apiNotFound: HttpHandler =
    routeStartsWith "/api" >=> setStatusCode 404 >=> text "Not found"

let spaFallback: HttpHandler =
    GET
    >=> setHttpHeader "Cache-Control" "no-cache"
    >=> htmlFile "public/index.html"

let webApp =
    choose [ router { forward "/api" apiRouter }; apiNotFound; spaFallback ]

let jwt (services: IServiceCollection) =
    let config = services.BuildServiceProvider().GetService<IConfiguration>()
    let validIssuer = config["Keycloak:ValidIssuer"]
    let metadata = config["Keycloak:Metadata"]

    services
        .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(fun (options: JwtBearerOptions) ->
            let tokenParameters = TokenValidationParameters()

            tokenParameters.ValidIssuer <- validIssuer
            tokenParameters.ValidateIssuerSigningKey <- true
            tokenParameters.ValidAudience <- "account"

            options.Audience <- "account"
            options.MetadataAddress <- metadata
            options.RequireHttpsMetadata <- false
            options.TokenValidationParameters <- tokenParameters)
    |> ignore

    services

let configureApp (builder: IApplicationBuilder) = builder.UseAuthentication()

let app =
    application {
        use_router webApp
        use_static "public"
        app_config configureApp
        service_config jwt
        memory_cache
        use_gzip
    }

[<EntryPoint>]
let main _ =
    run app
    0
