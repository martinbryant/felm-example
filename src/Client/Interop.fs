module Interop

open Fable.Core
open Fable.Core.JsInterop
open Browser.Types

/// Flags passed into Elm's `init` at boot. Elm auto-decodes a plain JS
/// object matching this shape into its own `Flags` record - no manual
/// Json.Decode wiring needed on either side for this.
type Flags =
    {
        authenticated: bool
        name: string
        token: string
    }

type ElmApp = { ports: obj }

type ElmMainModule =
    abstract init: options: obj -> ElmApp

type ElmNamespace = { Main: ElmMainModule }

/// vite-plugin-elm compiles elm/Main.elm and exposes it as a named `Elm`
/// export, keyed by the Elm module's own name ("Main"). Written relative to
/// this .fs file's own location (elm/ is a sibling directory) - Fable
/// rewrites the path to stay correct once compiled into ./output/.
let Elm: ElmNamespace = importMember "./elm/Main.elm"

let mount (node: Element) (flags: Flags) : ElmApp =
    Elm.Main.init (createObj [ "node" ==> node; "flags" ==> toPlainJsObj flags ])

/// Subscribes to an outgoing Elm port by name (e.g. "requestLogin").
let subscribePort (app: ElmApp) (portName: string) (handler: unit -> unit) =
    app.ports?(portName)?subscribe (fun (_: obj) -> handler ())
