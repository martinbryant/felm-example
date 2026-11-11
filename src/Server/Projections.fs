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
        this.SchemaObjects.Add table

    override _.ApplyAsync(ops: IDocumentOperations, e: IEvent, _: CancellationToken) : ValueTask =
        match e.Data with
        | :? TodoEvent as event ->
            match event with
            | TodoCreated data ->
                ops.QueueSqlCommand(
                    "insert into todo (id, tenant_id, description, created) values (?, ?, ?, ?)",
                    data.Id,
                    e.TenantId,
                    data.Description,
                    e.Timestamp
                )
            | TodoCompleted ->
                ops.QueueSqlCommand("update todo set completed = ? where id = ?", e.Timestamp, e.StreamId)
            | TodoDeleted -> ops.QueueSqlCommand("update todo set deleted = ? where id = ?", e.Timestamp, e.StreamId)
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
