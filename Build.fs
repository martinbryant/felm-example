open Fake.Core
open Fake.IO

open Helpers

initializeContext ()

let serverPath = Path.getFullName "src/Server"
let clientPath = Path.getFullName "src/Client"
let deployPath = Path.getFullName "deploy"

Target.create "Clean" (fun _ ->
    Shell.cleanDir deployPath
    run dotnet [ "fable"; "clean"; "--yes" ] clientPath // Delete *.fs.js files created by Fable
)

Target.create "RestoreClientDependencies" (fun _ -> run npm [ "ci" ] ".")

Target.create "Run" (fun _ ->
    [
        "server", dotnet [ "watch"; "run" ] serverPath
        "client", dotnet [ "fable"; "watch"; "-o"; "output"; "-s"; "--run"; "npx"; "vite" ] clientPath
    ]
    |> runParallel)

Target.create "Format" (fun _ ->
    run dotnet [ "fantomas"; "." ] "src"
    run elmFormat [ "elm"; "--yes" ] clientPath)

Target.create "CheckFormat" (fun _ ->
    run dotnet [ "fantomas"; "."; "--check" ] "src"
    run elmFormat [ "elm"; "--validate" ] clientPath)

open Fake.Core.TargetOperators

let dependencies = [ "Clean" ==> "RestoreClientDependencies" ==> "Run" ]

[<EntryPoint>]
let main args = runOrDefault args
