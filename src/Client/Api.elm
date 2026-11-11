module Api exposing (Cred, Error(..), credFromToken, delete, errorMessage, get, post, postEmpty)

{-| Client for the todo REST API under `/api/todo`. Every call needs the
`Cred` held by the `Session`.
-}

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| The access token that authorises API calls. Opaque so only `Api` can put it
in a request.
-}
type Cred
    = Cred String


credFromToken : String -> Cred
credFromToken =
    Cred


type Error
    = Unauthorized
    | Forbidden
    | NotFound
    | Other String


errorMessage : Error -> String
errorMessage error =
    case error of
        Unauthorized ->
            "Your session has expired - please log in again."

        Forbidden ->
            "You don't have permission to do this."

        NotFound ->
            "Not found."

        Other message ->
            message


get : Cred -> String -> Decoder a -> (Result Error a -> msg) -> Cmd msg
get cred path decoder toMsg =
    let
        expect =
            Http.expectJson (toResult toMsg) decoder
    in
    request "GET" cred path Http.emptyBody expect


post : Cred -> String -> Encode.Value -> Decoder a -> (Result Error a -> msg) -> Cmd msg
post cred path body decoder toMsg =
    let
        jsonBody =
            Http.jsonBody body

        expect =
            Http.expectJson (toResult toMsg) decoder
    in
    request "POST" cred path jsonBody expect


{-| Bodiless POST, e.g. `/api/todo/{id}/complete`.
-}
postEmpty : Cred -> String -> Decoder a -> (Result Error a -> msg) -> Cmd msg
postEmpty cred path decoder toMsg =
    let
        expect =
            Http.expectJson (toResult toMsg) decoder
    in
    request "POST" cred path Http.emptyBody expect


delete : Cred -> String -> (Result Error () -> msg) -> Cmd msg
delete cred path toMsg =
    let
        expect =
            Http.expectWhatever (toResult toMsg)
    in
    request "DELETE" cred path Http.emptyBody expect


request : String -> Cred -> String -> Http.Body -> Http.Expect msg -> Cmd msg
request method (Cred token) path body expect =
    Http.request
        { method = method
        , headers = [ Http.header "Authorization" ("Bearer " ++ token) ]
        , url = path
        , body = body
        , expect = expect
        , timeout = Nothing
        , tracker = Nothing
        }


toResult : (Result Error a -> msg) -> Result Http.Error a -> msg
toResult toMsg =
    Result.mapError toError >> toMsg


toError : Http.Error -> Error
toError error =
    case error of
        Http.BadStatus 401 ->
            Unauthorized

        Http.BadStatus 403 ->
            Forbidden

        Http.BadStatus 404 ->
            NotFound

        Http.BadStatus status ->
            Other ("The server returned status " ++ String.fromInt status ++ ".")

        Http.BadBody message ->
            Other ("Unexpected response: " ++ message)

        _ ->
            Other "Could not reach the server."
