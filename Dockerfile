FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

# Node (Vite 8 needs >= 20.19) for the client bundle
ARG NODE_MAJOR=22
RUN apt-get update \
    && apt-get install -y ca-certificates curl gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Elm compiler: the official release binary matching the build architecture
ARG TARGETARCH
ARG ELM_VERSION=0.19.3
RUN case "$TARGETARCH" in arm64) ELM_ARCH=arm ;; *) ELM_ARCH=x64 ;; esac \
    && curl -fsSL "https://github.com/elm/compiler/releases/download/$ELM_VERSION/elm-$ELM_VERSION-linux-$ELM_ARCH.gz" | gunzip > /usr/local/bin/elm \
    && chmod +x /usr/local/bin/elm \
    && elm --version

WORKDIR /workspace

# Dependencies first so they're cached until a manifest changes
COPY .config .config
RUN dotnet tool restore
COPY package.json package-lock.json ./
RUN npm ci

COPY . .

# Baked into the client bundle at build time (read by Vite as import.meta.env)
ARG VITE_AUTH_ORIGIN=https://auth.martinbryant.dev
ENV VITE_AUTH_ORIGIN=$VITE_AUTH_ORIGIN

RUN dotnet run --project Build.fsproj -- Bundle

FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine
COPY --from=build /workspace/deploy /app
WORKDIR /app
# aspnet images listen on 8080 by default (same as safe-stack-example)
EXPOSE 8080
ENTRYPOINT [ "dotnet", "Server.dll" ]
