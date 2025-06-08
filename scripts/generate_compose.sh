#!/bin/bash

# Generate docker-compose.yml for CI/CD
# This script creates a simple docker-compose configuration for testing

set -e

echo "Generating docker-compose.yml for CI/CD..."

# Create docker-compose.simple.yml
cat > docker-compose.simple.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_DB: odoo
      POSTGRES_USER: odoo
      POSTGRES_PASSWORD: odoo
      POSTGRES_HOST_AUTH_METHOD: trust
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U odoo"]
      interval: 10s
      timeout: 5s
      retries: 5
    volumes:
      - postgres_data:/var/lib/postgresql/data

  odoo:
    build: .
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - HOST=postgres
      - USER=odoo
      - PASSWORD=odoo
    ports:
      - "8069:8069"
    volumes:
      - ./addons:/mnt/extra-addons
      - ./config:/etc/odoo
    command: odoo --database=odoo --db_host=postgres --db_user=odoo --db_password=odoo --init=base --stop-after-init
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8069/web/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

volumes:
  postgres_data:

networks:
  default:
    name: odoo_network
EOF

echo "✅ docker-compose.simple.yml generated successfully"