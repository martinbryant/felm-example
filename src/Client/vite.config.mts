import { defineConfig } from "vite";
import elmPlugin from "vite-plugin-elm";

const proxyPort = process.env.SERVER_PROXY_PORT || "5000";
const proxyTarget = "http://localhost:" + proxyPort;

export default defineConfig({
    // .env lives at the repo root, not next to this config (Vite's root).
    // Without this VITE_AUTH_ORIGIN is undefined, Keycloak's iframe URLs
    // become relative, and Vite's SPA fallback serves the app inside them.
    envDir: "../..",
    // The npm "elm" package's installer is broken on Apple Silicon (it can't
    // detect the arch and fails downloading the binary), so the compiler is
    // installed via Homebrew instead and resolved from PATH here.
    plugins: [elmPlugin({ pathToElm: "elm" })],
    build: {
        outDir: "../../deploy/public",
    },
    server: {
        port: 8080,
        proxy: {
            "/api/": {
                target: proxyTarget,
                changeOrigin: true,
            }
        },
        watch: {
            ignored: [ "**/*.fs" ]
        },
    }
});
