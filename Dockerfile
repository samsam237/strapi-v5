# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Install build dependencies for native modules (better-sqlite3)
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json ./

# Install all dependencies (including devDependencies for build)
RUN npm ci && npm cache clean --force

# Copy source code
COPY . .

# Build Strapi admin panel
RUN npm run build

# Stage 2: Production
FROM node:20-alpine AS runner

WORKDIR /app

# Install runtime dependencies for better-sqlite3 and healthcheck
RUN apk add --no-cache python3 make g++ wget

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S strapi -u 1001

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production && npm cache clean --force

# Copy necessary files from builder and source
COPY --from=builder --chown=strapi:nodejs /app/build ./build
COPY --from=builder --chown=strapi:nodejs /app/dist ./dist
COPY --chown=strapi:nodejs ./public ./public
COPY --chown=strapi:nodejs ./config ./config
COPY --chown=strapi:nodejs ./database ./database
COPY --chown=strapi:nodejs ./src ./src
COPY --chown=strapi:nodejs ./tsconfig.json ./tsconfig.json
COPY --chown=strapi:nodejs ./favicon.png ./favicon.png

# Create directories for runtime data
RUN mkdir -p .tmp public/uploads && \
    chown -R strapi:nodejs .tmp public/uploads

# Switch to non-root user
USER strapi

# Expose port
EXPOSE 1337

# Health check - vérifie que le serveur répond sur le port 1337
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:1337 || exit 1

# Start Strapi
CMD ["npm", "start"]
