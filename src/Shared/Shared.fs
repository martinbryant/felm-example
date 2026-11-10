namespace Shared

open System

type CreatedData = { Id: Guid; Description: string }

type TodoEvent =
    | TodoCreated of CreatedData
    | TodoCompleted
    | TodoDeleted

[<CLIMutable>]
type TodoHistoryItem =
    { At: DateTimeOffset; Event: TodoEvent }

[<CLIMutable>]
type TodoHistory =
    {
        Id: Guid
        Items: TodoHistoryItem list
    }

[<CLIMutable>]
type Todo =
    {
        Id: Guid
        Description: string
        Created: DateTimeOffset
        Completed: DateTimeOffset option
        Deleted: DateTimeOffset option
    }

module Todo =
    let isValid (description: string) =
        String.IsNullOrWhiteSpace description |> not

module TodoEvent =
    let toString event =
        match event with
        | TodoCreated _ -> "Created"
        | TodoCompleted -> "Completed"
        | TodoDeleted -> "Deleted"
