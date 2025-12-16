# ---------- Base ----------
FROM node:18-alpine AS base

# Variables de entorno seguras
ENV PNPM_VERSION=9.1.2 \
    NODE_ENV=production \
    PNPM_HOME="/pnpm" \
    PATH="$PNPM_HOME:$PATH" \
    COREPACK_ENABLE_STRICT=1 \
    COREPACK_INTERRUPT_ON_OUTDATED=1

# Instalar pnpm de forma verificada via corepack
RUN corepack enable && corepack prepare pnpm@${PNPM_VERSION} --activate

# ---------- Dependencies ----------
FROM base AS deps
WORKDIR /app

# 1. Copiar solo los archivos necesarios para instalar dependencias
COPY package.json pnpm-lock.yaml* ./

# 2. Configuración segura de pnpm
RUN pnpm config set store-dir /pnpm-store && \
    pnpm config set strict-peer-dependencies true && \
    pnpm config set ignore-scripts true && \
    pnpm config set audit-level high && \
    pnpm config set prefer-frozen-lockfile true

# 3. Verificar integridad del lockfile antes de instalar
RUN sha256sum pnpm-lock.yaml > /tmp/lockfile.sha256 && \
    echo "✅ Lockfile checksum guardado"

# 4. Instalar solo dependencias de producción (sin scripts)
RUN --mount=type=cache,id=pnpm,target=/pnpm-store \
    pnpm fetch --prod && \
    pnpm install -P --frozen-lockfile --ignore-scripts && \
    pnpm store prune && \
    rm -rf /pnpm-store

# ---------- Builder ----------
FROM base AS builder
WORKDIR /app

# Variables de build
ARG NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_API_URL=${NEXT_PUBLIC_API_URL}

# Copiar node_modules verificado
COPY --from=deps /app/node_modules ./node_modules

# Copiar solo los archivos necesarios para el build (NO TODO)
COPY public ./public/
COPY src ./src/
COPY next.config.js ./
COPY tsconfig.json ./
COPY tailwind.config.js ./
COPY postcss.config.js ./
COPY package.json ./

# Verificar archivos antes del build
RUN find . -type f \( -name "*.js" -o -name "*.json" -o -name "*.ts" -o -name "*.tsx" \) \
    -exec grep -l "eval(\|base64_decode(\|system(\|shell_exec(\|child_process\|require('child_process')" {} \; \
    | grep -v node_modules | grep -v ".next" && \
    { echo "❌ Archivos sospechosos encontrados"; exit 1; } || echo "✅ Archivos verificados"

# Build de la aplicación
RUN pnpm run build

# Limpiar después del build
RUN rm -rf node_modules && \
    pnpm install -P --frozen-lockfile --ignore-scripts --shamefully-hoist

# ---------- Runner ----------
FROM node:18-alpine AS runner
WORKDIR /app

# Variables de entorno de producción
ENV NODE_ENV=production \
    PORT=3000

# Crear usuario no-root sin shell
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -u 1001 -H -G nodejs nextjs && \
    mkdir -p /app && \
    chown -R nextjs:nodejs /app

# Copiar solo lo absolutamente necesario
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Limpieza de seguridad
RUN npm uninstall -g pnpm corepack 2>/dev/null || true && \
    rm -rf /usr/local/lib/node_modules/npm && \
    rm -rf /root/.npm /root/.config /tmp/* /var/tmp/* && \
    apk del --no-cache npm 2>/dev/null || true

# Configurar permisos mínimos
RUN chmod -R 555 /app/.next && \
    chmod 755 /app/public && \
    chmod 755 /app/server.js && \
    find /app -type f -name "*.js" -exec chmod 555 {} \; && \
    find /app -type d -exec chmod 555 {} \;

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000 || exit 1

# Usuario no-root
USER nextjs

# Puerto
EXPOSE 3000

# Comando seguro (sin npm/pnpm)
CMD ["node", "server.js"]