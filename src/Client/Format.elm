module Format exposing (dateTime)

{-| Date formatting. Elm's core `Time` only gives numbers and `Weekday`/`Month`
tags, so the names and ordinals come from `justinmimbs/date`.
-}

import Date
import Time


{-| Like the SAFE example's `EEEE, do MMMM y 'at' H:mm`, in the given zone,
e.g. "Tuesday, 10th November 2026 at 19:42".
-}
dateTime : Time.Zone -> Time.Posix -> String
dateTime zone time =
    Date.format "EEEE, ddd MMMM y" (Date.fromPosix zone time)
        ++ " at "
        ++ String.fromInt (Time.toHour zone time)
        ++ ":"
        ++ String.padLeft 2 '0' (String.fromInt (Time.toMinute zone time))
