module Server

open System
open System.Security.Claims
open System.Text.Json
open System.Text.Json.Serialization
open JasperFx
open JasperFx.Events.Projections
open JasperFx.MultiTenancy
open Marten
open Dapper.FSharp.PostgreSQL
open Npgsql
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
let private tenantId (context: HttpContext) =
    context.User.FindFirst(ClaimTypes.NameIdentifier).Value

let private eventStorage (context: HttpContext) =
    let store = context.GetService<IDocumentStore>()
    let dataSource = context.GetService<NpgsqlDataSource>()
    EventStorage(store, dataSource)

let private forbidden =
    RequestErrors.FORBIDDEN "You don't have permission to do this"

let private canEdit = requiresRole "todo-edit" forbidden

let private canRemove = requiresRole "todo-remove" forbidden

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
    fun next context ->
        task {
            let storage = eventStorage context
            // Deleted todos are left out unless ?includeDeleted=true.
            let includeDeleted =
                match context.TryGetQueryStringValue "includeDeleted" with
                | Some value ->
                    match Boolean.TryParse value with
                    | true, parsed -> parsed
                    | _ -> false
                | None -> false

            let tenant = tenantId context
            let! todos = storage.GetTodos(tenant, includeDeleted)
            return! json todos next context
        }

let private getTodo (id: Guid) : HttpHandler =
    fun next context ->
        task {
            let storage = eventStorage context
            let tenant = tenantId context
            let! todo = storage.GetTodo(tenant, id)
            let isMissing = isNull (box todo)

            if isMissing then
                return! notFound next context
            else
                return! json todo next context
        }

let private getHistory (id: Guid) : HttpHandler =
    fun next context ->
        task {
            let storage = eventStorage context
            let tenant = tenantId context
            let! history = storage.GetHistory(tenant, id)
            let isMissing = isNull (box history)

            if isMissing then
                return! notFound next context
            else
                let entries = List.map toEntry history.Items
                return! json entries next context
        }

let private createTodo: HttpHandler =
    canEdit
    >=> fun next context ->
        task {
            let! body = context.BindJsonAsync<NewTodo>()
            let isInvalid = isNull (box body) || not (Todo.isValid body.Description)

            if isInvalid then
                return! RequestErrors.BAD_REQUEST "A description is required" next context
            else
                let storage = eventStorage context
                let tenant = tenantId context
                let id = Guid.NewGuid()

                let data =
                    {
                        Id = id
                        Description = body.Description.Trim()
                    }

                do! storage.AddTodo(tenant, data)

                let! todo = storage.GetTodo(tenant, id)
                let created = setStatusCode 201 >=> json todo
                return! created next context
        }

let private completeTodo (id: Guid) : HttpHandler =
    canEdit
    >=> fun next context ->
        task {
            let storage = eventStorage context
            let tenant = tenantId context
            let! existing = storage.GetTodo(tenant, id)
            let isMissing = isNull (box existing)

            if isMissing then
                return! notFound next context
            else
                do! storage.CompleteTodo(tenant, id)
                let! todo = storage.GetTodo(tenant, id)
                return! json todo next context
        }

let private removeTodo (id: Guid) : HttpHandler =
    canRemove
    >=> fun next context ->
        task {
            let storage = eventStorage context
            let tenant = tenantId context
            let! existing = storage.GetTodo(tenant, id)
            let isMissing = isNull (box existing)

            if isMissing then
                return! notFound next context
            else
                do! storage.RemoveTodo(tenant, id)
                return! setStatusCode 204 next context
        }

/// All todo endpoints live under /api/todo:
///   GET    /api/todo                 list (?includeDeleted=true to include deleted; default false)
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
    // Dapper.FSharp reads the `todo` table; it needs F# options mapped to nullable columns.
    OptionTypes.register ()

    services.AddSingleton<NpgsqlDataSource>(fun provider ->
        let config = provider.GetService<IConfiguration>()
        let connectionString = config.GetConnectionString "Db"
        NpgsqlDataSource.Create connectionString)
    |> ignore

    services
        .AddMarten(fun (options: StoreOptions) ->
            let config = services.BuildServiceProvider().GetService<IConfiguration>()
            let connectionString = config.GetConnectionString "Db"

            options.Connection connectionString
            options.AutoCreateSchemaObjects <- AutoCreate.CreateOrUpdate
            options.Events.TenancyStyle <- TenancyStyle.Conjoined

            options.Projections.Add(TodoProjection(), ProjectionLifecycle.Inline)
            options.Projections.Add(TodoHistoryProjection(), ProjectionLifecycle.Live)

            let configureJson (serializerOptions: JsonSerializerOptions) =
                let converter = JsonFSharpConverter()
                serializerOptions.Converters.Add converter

            options.UseSystemTextJsonForSerialization(configure = configureJson))
        // Marten creates its tables lazily on first use, but Dapper reads `todo`
        // without going through Marten, so create the schema when the app starts.
        .ApplyAllDatabaseChangesOnStartup()
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
