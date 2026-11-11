module Todo exposing (Event(..), HistoryItem, Todo, decoder, encodeNew, eventName, historyDecoder, isCompleted, isDeleted)

{-| The todo domain types and their JSON, as served by `/api/todo`.
-}

import Iso8601
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Time


type alias Todo =
    { id : String
    , description : String
    , created : Time.Posix
    , completed : Maybe Time.Posix
    , deleted : Maybe Time.Posix
    }


type Event
    = Created String
    | Completed
    | Deleted


type alias HistoryItem =
    { at : Time.Posix
    , event : Event
    }


isCompleted : Todo -> Bool
isCompleted todo =
    todo.completed /= Nothing


isDeleted : Todo -> Bool
isDeleted todo =
    todo.deleted /= Nothing


eventName : Event -> String
eventName event =
    case event of
        Created _ ->
            "Created"

        Completed ->
            "Completed"

        Deleted ->
            "Deleted"


decoder : Decoder Todo
decoder =
    let
        optionalTime =
            Decode.nullable Iso8601.decoder

        id =
            Decode.field "id" Decode.string

        description =
            Decode.field "description" Decode.string

        created =
            Decode.field "created" Iso8601.decoder

        completed =
            Decode.field "completed" optionalTime

        deleted =
            Decode.field "deleted" optionalTime
    in
    Decode.map5 Todo id description created completed deleted


encodeNew : String -> Encode.Value
encodeNew description =
    let
        value =
            Encode.string description
    in
    Encode.object [ ( "description", value ) ]


historyDecoder : Decoder (List HistoryItem)
historyDecoder =
    let
        at =
            Decode.field "at" Iso8601.decoder

        event =
            Decode.field "event" Decode.string
                |> Decode.andThen eventDecoder
    in
    Decode.list (Decode.map2 HistoryItem at event)


eventDecoder : String -> Decoder Event
eventDecoder kind =
    case kind of
        "created" ->
            Decode.field "description" Decode.string |> Decode.map Created

        "completed" ->
            Decode.succeed Completed

        "deleted" ->
            Decode.succeed Deleted

        _ ->
            Decode.fail ("Unknown todo event: " ++ kind)
