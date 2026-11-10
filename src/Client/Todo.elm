module Todo exposing (Event(..), HistoryItem, Todo, decoder, encodeNew, eventLabel, historyDecoder, isCompleted, isDeleted)

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


eventLabel : Event -> String
eventLabel event =
    case event of
        Created description ->
            "Created: " ++ description

        Completed ->
            "Completed"

        Deleted ->
            "Deleted"


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
