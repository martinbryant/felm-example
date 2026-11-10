module EventStore

open Marten
open System
open System.Linq
open Shared

type EventStorage(store: IDocumentStore) =
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
            use session = store.LightweightSession(tenantId)

            // NB: session.Query<Todo>().FirstOrDefaultAsync(fun t -> t.Id = id) bypasses
            // conjoined tenancy filtering (Marten optimizes single-predicate-by-Id lookups
            // to a fast path that ignores the tenant scope). Filtering with .Where(...) first
            // keeps it on the normal LINQ translation path, which does respect tenancy.
            return! session.Query<Todo>().Where(fun todo -> todo.Id = id).FirstOrDefaultAsync()
        }
        |> Async.AwaitTask

    member _.GetTodos(tenantId: string) =
        task {
            use session = store.LightweightSession(tenantId)

            return! session.Query<Todo>().ToListAsync()
        }
        |> Async.AwaitTask

    member _.GetHistory(tenantId: string, id: Guid) =
        task {
            use session = store.LightweightSession(tenantId)

            let! events = session.Events.AggregateStreamAsync<TodoHistory> id

            return events
        }
        |> Async.AwaitTask
