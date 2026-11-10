module Env

open Fable.Core

type Env = { VITE_AUTH_ORIGIN: string }

type Meta = { env: Env }
type Import = { meta: Meta }

[<Global("import")>]
let importObj: Import = jsNative<Import>

let VITE_AUTH_ORIGIN = importObj.meta.env.VITE_AUTH_ORIGIN
