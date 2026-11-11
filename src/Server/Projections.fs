module Projections

open System
open System.Threading
open System.Threading.Tasks
open JasperFx.Events
open Marten
open Marten.Events.Aggregation
open Marten.Events.Projections
open Weasel.Postgresql.Tables
open Shared

/// Projects the todo events into a plain `todo` table (inline, so the row is
/// written in the same transaction as the event). Marten owns the table's DDL via
/// `SchemaObjects`; reads go through Dapper.FSharp (see EventStorage).
type TodoProjection() as this =
    inherit EventProjection()

    do
        let table = Table("todo")
        table.AddColumn<Guid>("id").AsPrimaryKey() |> ignore
        table.AddColumn<string>("tenant_id").NotNull() |> ignore
        table.AddColumn<string>("description").NotNull() |> ignore
        table.AddColumn<DateTimeOffset>("created").NotNull() |> ignore
        table.AddColumn<DateTimeOffset>("completed") |> ignore
        table.AddColumn<DateTimeOffset>("deleted") |> ignore

        table.AddColumn<string>("status").NotNull().DefaultValueByString(TodoStatus.toString Current)
        |> ignore

        let index = IndexDefinition "idx_todo_tenant_status"
        index.Columns <- [| "tenant_id"; "status" |]
        table.Indexes.Add index
        this.SchemaObjects.Add table

    override _.ApplyAsync(ops: IDocumentOperations, e: IEvent, _: CancellationToken) : ValueTask =
        let current = TodoStatus.toString Current
        let completed = TodoStatus.toString Completed
        let deleted = TodoStatus.toString Deleted

        match e.Data with
        | :? TodoEvent as event ->
            match event with
            | TodoCreated data ->
                ops.QueueSqlCommand(
                    "insert into todo (id, tenant_id, description, created, status) values (?, ?, ?, ?, ?)",
                    data.Id,
                    e.TenantId,
                    data.Description,
                    e.Timestamp,
                    current
                )
            | TodoCompleted ->
                // Deleted wins: completing an already deleted todo leaves it deleted.
                ops.QueueSqlCommand(
                    "update todo set completed = ?, status = case when status = ? then status else ? end where id = ?",
                    e.Timestamp,
                    deleted,
                    completed,
                    e.StreamId
                )
            | TodoDeleted ->
                ops.QueueSqlCommand(
                    "update todo set deleted = ?, status = ? where id = ?",
                    e.Timestamp,
                    deleted,
                    e.StreamId
                )
        | _ -> ()

        ValueTask.CompletedTask

type TodoHistoryProjection() =
    inherit SingleStreamProjection<TodoHistory, Guid>()

    override _.Evolve(snapshot: TodoHistory, id: Guid, e: IEvent) : TodoHistory =
        let current =
            if isNull (box snapshot) then
                { Id = id; Items = [] }
            else
                snapshot

        match e.Data with
        | :? TodoEvent as event ->
            { current with
                Items = current.Items @ [ { At = e.Timestamp; Event = event } ]
            }
        | _ -> current
