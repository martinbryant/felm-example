import { defineConfig } from "vite";
import elmPlugin from "vite-plugin-elm";
import tailwindcss from "@tailwindcss/vite";

const proxyPort = process.env.SERVER_PROXY_PORT || "5000";
const proxyTarget = "http://localhost:" + proxyPort;

export default defineConfig({
    envDir: "../..",
    plugins: [tailwindcss(), elmPlugin({ pathToElm: "elm" })],
    build: {
        outDir: "../../deploy/public",
        // outDir is outside the Vite root, so opt in to clearing it.
        emptyOutDir: true,
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
