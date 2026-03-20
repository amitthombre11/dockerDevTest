# Docker Development Setup Guide

## Overview

This document explains the development setup for running a full-stack application with a **React frontend** (using Create React App) and a **Laravel backend** inside Docker containers with hot reloading enabled.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Port 3000                           │
│                   (Nginx Reverse Proxy)                  │
├──────────────────────┬──────────────────────────────────┤
│                      │                                   │
│   React Frontend     │      Laravel Backend             │
│   (Node.js)          │      (PHP 8.2)                   │
│   Port 3000          │      Port 8000                   │
│   Hot Reload: ✓      │      Hot Reload: ✓              │
│                      │                                   │
└──────────────────────┴───────────────────────────────────┘
         │                            │
         ├────────────────────────────┤
         │                            │
    ┌────▼─────────┐        ┌────────▼─────┐
    │ node_modules │        │    vendor     │
    │   (Mounted)  │        │   (Mounted)   │
    └──────────────┘        │   (Mounted)   │
                             └───────────────┘
         │                            │
    ┌────▼─────────┐        ┌────────▼──────────┐
    │  App Code    │        │  Local MySQL DB   │
    │  (Volume)    │        │  (Host Network)   │
    └──────────────┘        └───────────────────┘
```

---

## Prerequisites

### Required Software
- Docker & Docker Compose (latest versions)
- MySQL 8.0+ installed locally on your machine
- Git (for version control)

### Required Directories Structure
```
project-root/
├── docker-compose.yml          # Docker Compose configuration
├── nginx.conf                  # Nginx reverse proxy config
├── build.bash                  # Optional build script
├── msbteWebAdminFront/         # React frontend (CRA)
│   ├── Dockerfile.dev
│   ├── package.json
│   ├── src/
│   ├── public/
│   └── node_modules/           # Will be created by Docker
├── msbteWebAdminBack/          # Laravel backend
│   ├── Dockerfile.dev
│   ├── composer.json
│   ├── artisan
│   ├── app/
│   └── vendor/                 # Will be created by Docker
└── ssl/                        # SSL certificates (optional)
    ├── server.crt
    └── server.key
```

---

## Setup Instructions

### Step 1: Clone/Prepare Your Project Structure

Ensure you have:
- React project in `msbteWebAdminFront/`
- Laravel project in `msbteWebAdminBack/`
- `docker-compose.yml` in the root directory
- `nginx.conf` in the root directory

### Step 2: Configure MySQL Connection

Update your Laravel `.env` file with your local MySQL credentials:

```env
DB_CONNECTION=mysql
DB_HOST=host.docker.internal or your docker ip
DB_PORT=3306
DB_DATABASE=your_database_name
DB_USERNAME=root
DB_PASSWORD=your_password
```

**Important**: Use `host.docker.internal` as the hostname to connect from Docker containers to your local MySQL database.

### Step 3: Configure Frontend API Endpoint (Optional)

If using a `.env` file in your React project for API configuration:

```env
REACT_APP_API_URL=http://localhost:3000/api
```

### Step 4: SSL Certificates (Optional for HTTPS)

For HTTPS support on port 443, create SSL certificates:

```bash
mkdir -p ssl
openssl req -x509 -newkey rsa:4096 -keyout ssl/server.key -out ssl/server.crt -days 365 -nodes
```

---

## Running the Application

### Start All Services

```bash
docker-compose up --build -d
```

**What this does:**
- Builds React and Laravel Docker images
- Starts 3 services: frontend, backend, nginx
- Mounts your code volumes for live editing
- Binds port 3000 to Nginx reverse proxy

### Access the Application

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:3000/api
- **Direct Backend**: http://localhost:8000 (for testing)
- **HTTPS**: https://localhost (if SSL is configured)

### Stop All Services

```bash
docker-compose down
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f frontend
docker-compose logs -f backend
docker-compose logs -f nginx
```

---

## File Configuration Reference

### docker-compose.yml

This file defines three services:

#### Frontend Service
```yaml
frontend:
  build:
    context: ./msbteWebAdminFront
    dockerfile: Dockerfile.dev
  volumes:
    - ./msbteWebAdminFront:/app              # Code volume
    - /app/node_modules                      # Named volume for node_modules
  environment:
    - CHOKIDAR_USEPOLLING=true              # File watching for Docker
    - NODE_ENV=development
```

**Key Points:**
- `CHOKIDAR_USEPOLLING=true` enables file watcher in Docker for hot reload
- `node_modules` is a named volume (not synced with host) for performance
- Code changes trigger automatic React refresh

#### Backend Service
```yaml
backend:
  build:
    context: ./msbteWebAdminBack
    dockerfile: Dockerfile.dev
  volumes:
    - ./msbteWebAdminBack:/var/www/html     # Code volume
    - ./ssl:/etc/ssl                        # SSL certificates
  ports:
    - "8000:8000"                           # Direct access for testing
  extra_hosts:
    - "host.docker.internal:host-gateway"   # Access local MySQL
  environment:
    APP_ENV: local
    DB_HOST: host.docker.internal           # Points to local machine
    DB_DATABASE: your_db_name
    DB_USERNAME: root
    DB_PASSWORD: your_password
```

**Key Points:**
- `extra_hosts` allows connection to local services
- `8000:8000` mapping for direct backend access
- Environment variables configure Laravel

#### Nginx Service
```yaml
nginx:
  image: nginx:latest
  volumes:
    - ./nginx.conf:/etc/nginx/nginx.conf    # Reverse proxy config
  ports:
    - "3000:3000"                           # Single entry point
    - "443:443"                             # HTTPS
  depends_on:
    - backend
    - frontend
```

**Key Points:**
- Single port (3000) for both frontend and backend
- Routes `/api/*` to backend, other routes to frontend
- Starts only after frontend and backend are ready

### nginx.conf

Nginx acts as a reverse proxy with two main blocks:

#### HTTP Block (Port 3000)
```nginx
location /api/ {
    proxy_pass http://backend:8000/api/;    # Route API calls
}

location / {
    proxy_pass http://frontend:3000/;       # Route everything else
}
```

#### HTTPS Block (Port 443)
Same routing as HTTP, but with SSL certificates if configured.

**Important Headers:**
- `Upgrade` & `Connection`: Required for WebSocket support
- `X-Forwarded-For`, `X-Forwarded-Proto`: Pass real client info to backend

### Frontend Dockerfile.dev

```dockerfile
FROM node:22-slim

WORKDIR /app

# Install only production deps
RUN npm install -f

# Enable file polling for Docker
ENV CHOKIDAR_USEPOLLING=true

CMD ["npm", "start"]
```

**Why `-f` flag:**
- Force installs even with dependency conflicts
- Useful for development environments

### Backend Dockerfile.dev

```dockerfile
FROM existenz/webstack:8.2

# Install PHP 8.2 extensions
RUN apk add --no-cache php82-openssl php82-pdo_mysql ...

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php82 -- --install-dir=/usr/local/bin

# Install Laravel dependencies
RUN php82 /usr/local/bin/composer install

CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]
```

**Key Points:**
- Uses Alpine Linux for smaller image size
- PHP 8.2 with all required extensions pre-installed
- Composer manages PHP dependencies
- Laravel's dev server runs on 0.0.0.0:8000 (accessible to Nginx)

---

## Hot Reloading

### Frontend (React CRA)
- **Mechanism**: Node.js file watcher (Chokidar)
- **How it works**: When you save a file, Webpack recompiles and hot-reloads in browser
- **Setup**: `CHOKIDAR_USEPOLLING=true` environment variable enables polling in Docker
- **Performance**: Named volume for `node_modules` prevents watching thousands of files

### Backend (Laravel)
- **Mechanism**: PHP artisan serve with file watching
- **How it works**: Changes to PHP files trigger automatic recompilation
- **Setup**: Volume mount `/var/www/html` enables real-time file changes
- **Performance**: Laravel caches aren't cleared automatically; use artisan commands as needed

---

## Common Development Tasks

### Running Laravel Artisan Commands

```bash
# Inside running container
docker-compose exec backend php artisan migrate
docker-compose exec backend php artisan tinker
docker-compose exec backend php artisan cache:clear

# Or run directly
docker-compose run backend php artisan migrate
```

### Running npm Commands for Frontend

```bash
# Install new package
docker-compose exec frontend npm install package-name

# Run build
docker-compose exec frontend npm run build

# Run tests
docker-compose exec frontend npm test
```

### Rebuilding Containers

```bash
# Rebuild without cache
docker-compose up --build --no-cache

# Rebuild specific service
docker-compose up --build backend
```

### Clearing Docker Cache

```bash
# Remove all containers and volumes
docker-compose down -v

# Start fresh
docker-compose up --build
```

---

## Troubleshooting

### Backend Won't Start

**Issue**: PHP errors or connection failures

**Solutions**:
```bash
# Check logs
docker-compose logs -f backend

# Verify MySQL connection on host
mysql -u root -p -h 127.0.0.1

# Ensure .env has correct DB credentials
# DB_HOST must be host.docker.internal
```

### Frontend Hot Reload Not Working

**Issue**: Changes not reflected in browser

**Solutions**:
```bash
# Verify CHOKIDAR_USEPOLLING is set
docker-compose exec frontend echo $CHOKIDAR_USEPOLLING

# Rebuild frontend service
docker-compose up --build frontend

# Clear browser cache (Ctrl+Shift+R)
```

### Port Already in Use

**Issue**: "Port 3000 already in use"

**Solutions**:
```bash
# Find process using port 3000
lsof -i :3000

# Kill the process
kill -9 <PID>

# Or use different port in docker-compose.yml
# ports:
#   - "3001:3000"
```

### MySQL Connection Refused

**Issue**: Backend can't connect to MySQL

**Verify**:
- MySQL is running on local machine: `mysql -u root -p`
- Use `host.docker.internal` in `.env` (NOT localhost)
- Check firewall/port access
- Verify credentials in `.env`

### node_modules Issues

**Issue**: Package installation fails or modules not found

**Solutions**:
```bash
# Clear and reinstall
docker-compose down -v
docker-compose up --build frontend

# Or manually clean
docker exec frontend rm -rf node_modules package-lock.json
docker-compose up --build frontend
```

---

## Extending the Setup

### Adding a New Service (Database, Cache, etc.)

1. Add service to `docker-compose.yml`:

```yaml
redis:
  image: redis:latest
  ports:
    - "6379:6379"
  networks:
    - app-network
```

2. Update `depends_on` in other services:

```yaml
backend:
  depends_on:
    - redis
```

3. Update Nginx if needed to proxy the service

### Using Environment-Specific Configs

Create separate compose files:
- `docker-compose.yml` (base)
- `docker-compose.prod.yml` (production overrides)

```bash
# Run with production config
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up
```

---

## Performance Tips

1. **Use Named Volumes for Dependencies**
   - Keep `node_modules` and `vendor` as volumes, not synced
   - Reduces file sync overhead

2. **Enable BuildKit**
   ```bash
   export DOCKER_BUILDKIT=1
   docker-compose build
   ```

3. **Use `.dockerignore`**
   ```
   .git
   node_modules
   vendor
   .env.local
   storage/logs
   ```

4. **Increase Docker Resources**
   - Desktop Docker: Preferences → Resources → Increase CPU/Memory

5. **Use Polling Only When Necessary**
   - CHOKIDAR_USEPOLLING can be disabled on Linux: set to false

---

## Best Practices

### 1. Git Ignore Docker Artifacts
```gitignore
# Docker
.env.local
docker-compose.override.yml
.docker/

# Dependencies (built by Docker)
msbteWebAdminFront/node_modules
msbteWebAdminBack/vendor
```

### 2. Keep Images Lean
- Use Alpine Linux Base images
- Multi-stage builds for production
- Exclude unnecessary files

### 3. Security
- Don't commit `.env` with passwords
- Use `.env.example` with placeholder values
- Regenerate SSL certificates for production

### 4. Logs
- Use Docker volumes for persistent logs
- Set log rotation in Docker daemon config
- Monitor container resource usage

### 5. Code Organization
```
project/
├── docker-compose.yml
├── nginx.conf
├── .dockerignore
├── .env.example
└── docker/
    ├── backend/
    │   └── Dockerfile.dev
    └── frontend/
        └── Dockerfile.dev
```

---

## Quick Reference Commands

```bash
# Basic operations
docker-compose up                    # Start all services
docker-compose up --build            # Start and rebuild
docker-compose down                  # Stop all services
docker-compose down -v               # Stop and remove volumes

# Debugging
docker-compose logs -f               # View all logs
docker-compose logs -f backend       # View backend logs
docker-compose exec backend bash     # Access backend container
docker-compose exec frontend sh      # Access frontend container

# Database
docker-compose exec backend php artisan migrate
docker-compose exec backend php artisan db:seed

# Dependencies
docker-compose exec frontend npm install package-name
docker-compose exec backend composer require package/name

# Performance
docker-compose stats                 # Resource usage
docker image ls                      # List images
docker volume ls                     # List volumes
```

---

## Conclusion

This setup provides a professional development environment with:
- ✅ Hot reloading for rapid development
- ✅ Isolated services in containers
- ✅ Easy dependency management
- ✅ Connection to local databases
- ✅ Production-like networking with Nginx
- ✅ Single entry point (Port 3000)

Happy coding! 🚀
