// Fable's --run starts this from fsharp/, but vite-plugin-elm builds its HMR
// dependency paths relative to process.cwd(), so Vite has to be launched from
// its root (src/Client). Otherwise a multi-module Elm app fails with
// `Failed to resolve "/../Effect.elm"`. Usage: node vite.mjs [vite args]
import { spawn } from "node:child_process";

const child = spawn("npx", ["vite", ...process.argv.slice(2)], {
    cwd: new URL("..", import.meta.url),
    stdio: "inherit",
});

for (const signal of ["SIGINT", "SIGTERM"]) {
    process.on(signal, () => child.kill(signal));
}
child.on("exit", code => process.exit(code ?? 1));
