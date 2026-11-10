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

// Dev-only server: Vite (:8080) serves the client and its own SPA fallback
// handles direct navigation to "/login". This server only answers "/api/*" —
// static-file serving and SPA-fallback routes only become relevant once a
// production bundle combines server + built client assets, which is out of
// scope for this pass.
let webApp = router { forward "/api" apiRouter }

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
        app_config configureApp
        service_config jwt
        memory_cache
        use_gzip
    }

[<EntryPoint>]
let main _ =
    run app
    0
