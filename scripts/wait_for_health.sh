#!/bin/bash

# Wait for services to be healthy
# This script waits for all services to pass their health checks

set -e

echo "Waiting for services to be healthy..."

# Function to check if a service is healthy
check_service_health() {
    local service_name=$1
    local max_attempts=30
    local attempt=1
    
    echo "Checking health of service: $service_name"
    
    while [ $attempt -le $max_attempts ]; do
        health_status=$(docker-compose -f docker-compose.simple.yml ps -q $service_name | xargs docker inspect --format='{{.State.Health.Status}}' 2>/dev/null || echo "starting")
        
        if [ "$health_status" = "healthy" ]; then
            echo "✅ $service_name is healthy"
            return 0
        elif [ "$health_status" = "unhealthy" ]; then
            echo "❌ $service_name is unhealthy"
            docker-compose -f docker-compose.simple.yml logs $service_name
            return 1
        else
            echo "⏳ $service_name is $health_status (attempt $attempt/$max_attempts)"
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    echo "❌ Timeout waiting for $service_name to be healthy"
    docker-compose -f docker-compose.simple.yml logs $service_name
    return 1
}

# Wait for postgres to be healthy
check_service_health "postgres"

# Wait a bit more for postgres to be fully ready
echo "Waiting additional 10 seconds for postgres to be fully ready..."
sleep 10

# Check if postgres is accepting connections
echo "Testing postgres connection..."
docker-compose -f docker-compose.simple.yml exec -T postgres psql -U odoo -d odoo -c "SELECT 1;" > /dev/null
if [ $? -eq 0 ]; then
    echo "✅ Postgres connection test successful"
else
    echo "❌ Postgres connection test failed"
    exit 1
fi

echo "✅ All services are healthy and ready"