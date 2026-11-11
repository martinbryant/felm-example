# felm-example

Elm client (`src/Client`), F# server (`src/Server`, Marten + Dapper.FSharp), shared types in `src/Shared`.
This is an Elm port of `../safe-stack-example`; keep behaviour in step with it unless told otherwise.

## Code standards

1. **Assign before passing.** Don't call a function inside the argument list of another call; bind the result to a
   named variable first, then pass the variable.
   - Avoid: `NpgsqlDataSource.Create(provider.GetService<IConfiguration>().GetConnectionString "Db")`
   - Prefer: `let config = provider.GetService<IConfiguration>()` / `let connectionString = config.GetConnectionString "Db"` / `NpgsqlDataSource.Create connectionString`
   - Pipelines (`|>`) and simple constructors/field access are fine.
2. **Full lambda parameter names.** Name lambda parameters for what they are, not by initials:
   `fun provider ->`, not `fun sp ->`; `fun todo ->`, not `fun t ->`. (`_` for unused is fine.)
