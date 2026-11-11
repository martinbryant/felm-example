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
    Decode.map5 Todo
        (Decode.field "id" Decode.string)
        (Decode.field "description" Decode.string)
        (Decode.field "created" Iso8601.decoder)
        (Decode.field "completed" (Decode.nullable Iso8601.decoder))
        (Decode.field "deleted" (Decode.nullable Iso8601.decoder))


encodeNew : String -> Encode.Value
encodeNew description =
    Encode.object [ ( "description", Encode.string description ) ]


historyDecoder : Decoder (List HistoryItem)
historyDecoder =
    Decode.list
        (Decode.map2 HistoryItem
            (Decode.field "at" Iso8601.decoder)
            (Decode.field "event" Decode.string
                |> Decode.andThen
                    (\kind ->
                        case kind of
                            "created" ->
                                Decode.field "description" Decode.string |> Decode.map Created

                            "completed" ->
                                Decode.succeed Completed

                            "deleted" ->
                                Decode.succeed Deleted

                            _ ->
                                Decode.fail ("Unknown todo event: " ++ kind)
                    )
            )
        )
