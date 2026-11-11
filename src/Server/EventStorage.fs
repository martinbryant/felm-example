module EventStore

open Dapper.FSharp.PostgreSQL
open Marten
open Npgsql
open System
open Shared

/// A row of the `todo` table; field names are the column names.
[<CLIMutable>]
type TodoRow =
    {
        id: Guid
        tenant_id: string
        description: string
        created: DateTime
        completed: DateTime option
        deleted: DateTime option
        status: string
    }

let private todoTable = table'<TodoRow> "todo"

let private asOffset (dateTime: DateTime) =
    let utc = DateTime.SpecifyKind(dateTime, DateTimeKind.Utc)
    DateTimeOffset utc

let private toTodo (row: TodoRow) : Todo =
    {
        Id = row.id
        Description = row.description
        Created = asOffset row.created
        Completed = Option.map asOffset row.completed
        Deleted = Option.map asOffset row.deleted
    }

type EventStorage(store: IDocumentStore, dataSource: NpgsqlDataSource) =
    member _.AddTodo(tenantId: string, data: CreatedData) =
        task {
            use session = store.LightweightSession(tenantId)

            let event = TodoCreated data
            let todoId = data.Id

            session.Events.Append(todoId, event) |> ignore

            do! session.SaveChangesAsync()
        }
        |> Async.AwaitTask

    member _.CompleteTodo(tenantId: string, id: Guid) =
        task {
            use session = store.LightweightSession(tenantId)

            let event = TodoCompleted
            let todoId = id

            session.Events.Append(todoId, event) |> ignore

            do! session.SaveChangesAsync()
        }
        |> Async.AwaitTask

    member _.RemoveTodo(tenantId: string, id: Guid) =
        task {
            use session = store.LightweightSession(tenantId)

            let event = TodoDeleted
            let todoId = id

            session.Events.Append(todoId, event) |> ignore

            do! session.SaveChangesAsync()
        }
        |> Async.AwaitTask

    member _.GetTodo(tenantId: string, id: Guid) =
        task {
            use! connection = dataSource.OpenConnectionAsync()

            let! rows =
                select {
                    for row in todoTable do
                        where (row.tenant_id = tenantId && row.id = id)
                }
                |> connection.SelectAsync<TodoRow>

            return rows |> Seq.tryHead |> Option.map toTodo |> Option.toObj
        }
        |> Async.AwaitTask

    member _.GetTodos(tenantId: string, status: TodoStatus) =
        task {
            use! connection = dataSource.OpenConnectionAsync()

            let statusText = TodoStatus.toString status

            let! rows =
                select {
                    for row in todoTable do
                        where (row.tenant_id = tenantId && row.status = statusText)
                        orderBy row.created
                }
                |> connection.SelectAsync<TodoRow>

            return rows |> Seq.map toTodo |> List.ofSeq
        }
        |> Async.AwaitTask

    member _.GetHistory(tenantId: string, id: Guid) =
        task {
            use session = store.LightweightSession(tenantId)

            let! events = session.Events.AggregateStreamAsync<TodoHistory> id

            return events
        }
        |> Async.AwaitTask
