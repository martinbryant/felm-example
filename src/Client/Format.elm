module Format exposing (dateTime)

import Date
import Time


dateTime : Time.Zone -> Time.Posix -> String
dateTime zone time =
    let
        date =
            Date.fromPosix zone time

        day =
            Date.format "EEEE, ddd MMMM y" date

        hour =
            String.fromInt (Time.toHour zone time)

        minute =
            String.fromInt (Time.toMinute zone time)

        paddedMinute =
            String.padLeft 2 '0' minute
    in
    day ++ " at " ++ hour ++ ":" ++ paddedMinute
