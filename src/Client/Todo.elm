module Todo exposing (Event(..), HistoryItem, Todo, decoder, encodeNew, eventName, historyDecoder, isCompleted, isDeleted, shortDate)

{-| The todo domain types and their JSON, as served by `/api/todo`.
-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


type alias Todo =
    { id : String
    , description : String
    , created : String
    , completed : Maybe String
    , deleted : Maybe String
    }


type Event
    = Created String
    | Completed
    | Deleted


type alias HistoryItem =
    { at : String
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


{-| "2026-11-10T19:42:04.1+00:00" -> "2026-11-10 19:42".
-}
shortDate : String -> String
shortDate iso =
    String.left 10 iso ++ " " ++ String.slice 11 16 iso


decoder : Decoder Todo
decoder =
    Decode.map5 Todo
        (Decode.field "id" Decode.string)
        (Decode.field "description" Decode.string)
        (Decode.field "created" Decode.string)
        (Decode.field "completed" (Decode.nullable Decode.string))
        (Decode.field "deleted" (Decode.nullable Decode.string))


encodeNew : String -> Encode.Value
encodeNew description =
    Encode.object [ ( "description", Encode.string description ) ]


historyDecoder : Decoder (List HistoryItem)
historyDecoder =
    Decode.list
        (Decode.map2 HistoryItem
            (Decode.field "at" Decode.string)
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
