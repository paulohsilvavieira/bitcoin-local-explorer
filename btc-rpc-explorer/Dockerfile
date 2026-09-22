# syntax=docker/dockerfile:1

# =========================================================================
# Stage 1: deps — instala dependências (com devDependencies, necessário
# para compilar os módulos nativos como zeromq/tiny-secp256k1).
# Mesma base do runtime (alpine/musl) para não copiar binários nativos
# compilados contra uma libc incompatível.
# =========================================================================
FROM node:20-alpine AS deps
WORKDIR /workspace

RUN apk add --no-cache python3 make g++

COPY package.json npm-shrinkwrap.json ./
RUN npm ci

# =========================================================================
# Stage 2: prod-deps — mesma árvore, sem devDependencies (eslint/sass).
# =========================================================================
FROM deps AS prod-deps
RUN npm prune --omit=dev

# =========================================================================
# Stage 3: runtime — imagem final, sem toolchain de build, sem git,
# sem .git/, usuário não-root.
# =========================================================================
FROM node:20-alpine AS runtime
WORKDIR /workspace

ENV NODE_ENV=production

RUN addgroup -S app && adduser -S app -G app && chown app:app /workspace

COPY --from=prod-deps --chown=app:app /workspace/node_modules ./node_modules
COPY --chown=app:app . .

USER app

EXPOSE 3002

HEALTHCHECK --interval=15s --timeout=5s --start-period=15s --retries=5 \
    CMD wget -qO- http://127.0.0.1:3002/ >/dev/null || exit 1

CMD ["node", "./bin/www"]
