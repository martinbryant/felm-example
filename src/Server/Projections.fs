module Projections

open System
open JasperFx.Events
open Marten.Events.Aggregation
open Shared

type TodoProjection() =
    inherit SingleStreamProjection<Todo, Guid>()

    override _.Evolve(snapshot: Todo, id: Guid, e: IEvent) : Todo =
        let current =
            if isNull (box snapshot) then
                {
                    Id = id
                    Description = ""
                    Created = DateTimeOffset.MinValue
                    Completed = None
                    Deleted = None
                }
            else
                snapshot

        match e.Data with
        | :? TodoEvent as event ->
            match event with
            | TodoCreated data ->
                {
                    Id = data.Id
                    Description = data.Description
                    Created = e.Timestamp
                    Completed = None
                    Deleted = None
                }
            | TodoCompleted ->
                { current with
                    Completed = Some e.Timestamp
                }
            | TodoDeleted ->
                { current with
                    Deleted = Some e.Timestamp
                }
        | _ -> current

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
