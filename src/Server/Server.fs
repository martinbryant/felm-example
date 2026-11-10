module Server

open System
open System.Security.Claims
open System.Text.Json
open System.Text.Json.Serialization
open JasperFx
open JasperFx.Events.Projections
open JasperFx.MultiTenancy
open Marten
open EventStore
open Projections
open Shared
open Microsoft.AspNetCore.Authentication.JwtBearer
open Microsoft.AspNetCore.Builder
open Microsoft.AspNetCore.Http
open Microsoft.Extensions.Configuration
open Microsoft.Extensions.DependencyInjection
open Microsoft.IdentityModel.Tokens
open Saturn
open Giraffe

/// Todos are partitioned per user: the Keycloak subject is the Marten tenant.
let private tenantId (ctx: HttpContext) =
    ctx.User.FindFirst(ClaimTypes.NameIdentifier).Value

let private eventStorage (ctx: HttpContext) =
    EventStorage(ctx.GetService<IDocumentStore>())

let private canEdit =
    requiresRole "todo-edit" (RequestErrors.FORBIDDEN "You don't have permission to do this")

let private canRemove =
    requiresRole "todo-remove" (RequestErrors.FORBIDDEN "You don't have permission to do this")

let private notFound = RequestErrors.NOT_FOUND "Todo not found"

type NewTodo = { Description: string }

/// What the history endpoint returns: events flattened to something a client
/// can read without knowing the F# union encoding.
type HistoryEntry =
    {
        At: DateTimeOffset
        Event: string
        Description: string option
    }

let private toEntry (item: TodoHistoryItem) =
    match item.Event with
    | TodoCreated data ->
        {
            At = item.At
            Event = "created"
            Description = Some data.Description
        }
    | TodoCompleted ->
        {
            At = item.At
            Event = "completed"
            Description = None
        }
    | TodoDeleted ->
        {
            At = item.At
            Event = "deleted"
            Description = None
        }

let private listTodos: HttpHandler =
    fun next ctx ->
        task {
            let storage = eventStorage ctx
            let! todos = storage.GetTodos(tenantId ctx)
            return! json (List.ofSeq todos) next ctx
        }

let private getTodo (id: Guid) : HttpHandler =
    fun next ctx ->
        task {
            let storage = eventStorage ctx
            let! todo = storage.GetTodo(tenantId ctx, id)

            if isNull (box todo) then
                return! notFound next ctx
            else
                return! json todo next ctx
        }

let private getHistory (id: Guid) : HttpHandler =
    fun next ctx ->
        task {
            let storage = eventStorage ctx
            let! history = storage.GetHistory(tenantId ctx, id)

            if isNull (box history) then
                return! notFound next ctx
            else
                return! json (List.map toEntry history.Items) next ctx
        }

let private createTodo: HttpHandler =
    canEdit
    >=> fun next ctx ->
        task {
            let! body = ctx.BindJsonAsync<NewTodo>()

            if isNull (box body) || not (Todo.isValid body.Description) then
                return! RequestErrors.BAD_REQUEST "A description is required" next ctx
            else
                let storage = eventStorage ctx
                let id = Guid.NewGuid()

                do!
                    storage.AddTodo(
                        tenantId ctx,
                        {
                            Id = id
                            Description = body.Description.Trim()
                        }
                    )

                let! todo = storage.GetTodo(tenantId ctx, id)
                return! (setStatusCode 201 >=> json todo) next ctx
        }

let private completeTodo (id: Guid) : HttpHandler =
    canEdit
    >=> fun next ctx ->
        task {
            let storage = eventStorage ctx
            let! existing = storage.GetTodo(tenantId ctx, id)

            if isNull (box existing) then
                return! notFound next ctx
            else
                do! storage.CompleteTodo(tenantId ctx, id)
                let! todo = storage.GetTodo(tenantId ctx, id)
                return! json todo next ctx
        }

let private removeTodo (id: Guid) : HttpHandler =
    canRemove
    >=> fun next ctx ->
        task {
            let storage = eventStorage ctx
            let! existing = storage.GetTodo(tenantId ctx, id)

            if isNull (box existing) then
                return! notFound next ctx
            else
                do! storage.RemoveTodo(tenantId ctx, id)
                return! setStatusCode 204 next ctx
        }

/// All todo endpoints live under /api/todo:
///   GET    /api/todo                 list
///   POST   /api/todo                 create        { "description": "..." }
///   GET    /api/todo/{id}            one todo
///   GET    /api/todo/{id}/history    its events
///   POST   /api/todo/{id}/complete   mark completed
///   DELETE /api/todo/{id}            mark deleted
let todoRoutes: HttpHandler =
    requiresAuthentication (challenge JwtBearerDefaults.AuthenticationScheme)
    // The list changes under the client's feet (complete, delete); never let a
    // browser answer a GET from its cache.
    >=> setHttpHeader "Cache-Control" "no-store"
    >=> subRoute
            "/api/todo"
            (choose
                [
                    GET
                    >=> choose
                            [
                                routex "/?" >=> listTodos
                                routef "/%O/history" getHistory
                                routef "/%O" getTodo
                            ]
                    POST
                    >=> choose [ routex "/?" >=> createTodo; routef "/%O/complete" completeTodo ]
                    DELETE >=> routef "/%O" removeTodo
                ])

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
    choose [ routeStartsWith "/api/todo" >=> todoRoutes; apiNotFound; spaFallback ]

let marten (services: IServiceCollection) =
    services.AddMarten(fun (options: StoreOptions) ->
        let config = services.BuildServiceProvider().GetService<IConfiguration>()

        options.Connection(config.GetConnectionString "Db")
        options.AutoCreateSchemaObjects <- AutoCreate.CreateOrUpdate
        options.Events.TenancyStyle <- TenancyStyle.Conjoined

        options.Projections.Add(TodoProjection(), ProjectionLifecycle.Inline)
        options.Projections.Add(TodoHistoryProjection(), ProjectionLifecycle.Live)

        options.Schema.For<Todo>().MultiTenanted() |> ignore

        options.UseSystemTextJsonForSerialization(configure = _.Converters.Add(JsonFSharpConverter())))
    |> ignore

    services

let jwt (services: IServiceCollection) =
    let config = services.BuildServiceProvider().GetService<IConfiguration>()
    let validIssuer = config["Keycloak:ValidIssuer"]
    let metadata = config["Keycloak:Metadata"]

    services
        .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(fun (options: JwtBearerOptions) ->
            let tokenParameters = TokenValidationParameters()

            tokenParameters.NameClaimType <- ClaimTypes.Name
            tokenParameters.RoleClaimType <- ClaimTypes.Role
            tokenParameters.ValidIssuer <- validIssuer
            tokenParameters.ValidateIssuerSigningKey <- true
            tokenParameters.ValidAudience <- "account"

            options.Audience <- "account"
            options.MetadataAddress <- metadata
            options.RequireHttpsMetadata <- false
            options.TokenValidationParameters <- tokenParameters)
    |> ignore

    services

/// The API speaks camelCase JSON, with F# options as null/absent values.
let jsonSerializer =
    let options =
        JsonSerializerOptions(PropertyNamingPolicy = JsonNamingPolicy.CamelCase)

    options.Converters.Add(JsonFSharpConverter())
    Json.Serializer(options)

let configureApp (builder: IApplicationBuilder) = builder.UseAuthentication()

let app =
    application {
        use_router webApp
        use_json_serializer jsonSerializer
        use_static "public"
        app_config configureApp
        service_config (marten >> jwt)
        memory_cache
        use_gzip
    }

[<EntryPoint>]
let main _ =
    run app
    0
