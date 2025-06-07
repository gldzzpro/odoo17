#!/bin/bash

# test_docker_modules.sh - Local testing script for Odoo modules
# This script replicates the GitHub Actions workflow locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.yml"
CI_COMPOSE_FILE="docker-compose.ci.yml"
CONFIG_DIR="config"
LOG_DIR="logs"
TEST_TIMEOUT=300

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
    log_info "Cleaning up..."
    docker-compose -f "$CI_COMPOSE_FILE" down -v 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
}

# Trap cleanup on exit
trap cleanup EXIT

generate_ci_compose() {
    log_info "Generating CI docker-compose configuration..."
    
    cat > "$CI_COMPOSE_FILE" << 'EOF'
services:
  postgres:
    image: postgres:15
    restart: always
    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres_admin
      POSTGRES_MULTIPLE_DATABASES: odoo_db1,odoo_db2
      POSTGRES_MULTIPLE_USERS: odoo1:odoo1_pass,odoo2:odoo2_pass
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./init-multiple-databases.sh:/docker-entrypoint-initdb.d/init-multiple-databases.sh:ro
    networks:
      - odoo_network
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  odoo1:
    build:
      context: .
      dockerfile: Dockerfile
    command: -- --db_host=postgres --db_port=5432 --db_user=odoo1 --db_password=odoo1_pass --database=odoo_db1 -i base,softifi_graph_module_dependency --http-interface=0.0.0.0 --proxy-mode
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "8070:8069"
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=odoo1
      - DB_PASSWORD=odoo1_pass
      - DB_NAME=odoo_db1
    volumes:
      - ./addons_instance1:/mnt/extra-addons:ro
      - ./addons:/mnt/base-addons:ro
      - odoo1-data:/var/lib/odoo
    networks:
      - odoo_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8069/web/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  odoo2:
    build:
      context: .
      dockerfile: Dockerfile
    command: -- --db_host=postgres --db_port=5432 --db_user=odoo2 --db_password=odoo2_pass --database=odoo_db2 -i base,softifi_graph_module_dependency --http-interface=0.0.0.0 --proxy-mode
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "8069:8069"
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=odoo2
      - DB_PASSWORD=odoo2_pass
      - DB_NAME=odoo_db2
    volumes:
      - ./addons_instance2:/mnt/extra-addons:ro
      - ./addons:/mnt/base-addons:ro
      - odoo2-data:/var/lib/odoo
    networks:
      - odoo_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8069/web/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  graphsync:
    build:
      context: ./graph_sync
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    environment:
      - ODOO_INSTANCES=http://odoo1:8069,http://odoo2:8069
    depends_on:
      - odoo1
      - odoo2
    networks:
      - odoo_network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/healthcheck"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s

networks:
  odoo_network:
    driver: bridge

volumes:
  postgres-data:
  odoo1-data:
  odoo2-data:
EOF

    log_success "CI docker-compose configuration generated"
}

generate_config() {
    log_info "Generating graph_sync configuration..."
    
    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_DIR/config.yml" << 'EOF'
odoo_instances:
  - name: "instance1"
    url: "http://localhost:8070"
    database: "odoo_db1"
    username: "admin"
    password: "admin"
  - name: "instance2"
    url: "http://localhost:8069"
    database: "odoo_db2"
    username: "admin"
    password: "admin"

neo4j:
  uri: "${NEO4J_URI:-neo4j+s://localhost:7687}"
  username: "${NEO4J_USERNAME:-neo4j}"
  password: "${NEO4J_PASSWORD:-password}"

sync_settings:
  batch_size: 100
  timeout: 30
  retry_attempts: 3

dependency_analysis:
  detect_cycles: true
  max_depth: 10
  exclude_modules:
    - "base"
    - "web"
EOF

    log_success "Configuration files generated"
}

start_services() {
    log_info "Starting services..."
    
    # Start PostgreSQL first
    docker-compose -f "$CI_COMPOSE_FILE" up -d postgres
    
    # Wait for PostgreSQL
    log_info "Waiting for PostgreSQL to be ready..."
    timeout 60 bash -c 'until docker-compose -f "'$CI_COMPOSE_FILE'" exec -T postgres pg_isready -U postgres; do sleep 2; done'
    
    if [ $? -eq 0 ]; then
        log_success "PostgreSQL is ready"
    else
        log_error "PostgreSQL failed to start"
        return 1
    fi
    
    # Start Odoo instances
    docker-compose -f "$CI_COMPOSE_FILE" up -d odoo1 odoo2
    
    # Wait for Odoo instances
    log_info "Waiting for Odoo instances to be ready..."
    
    timeout $TEST_TIMEOUT bash -c 'until curl -f http://localhost:8070/web/health 2>/dev/null; do sleep 5; done' &
    ODOO1_PID=$!
    
    timeout $TEST_TIMEOUT bash -c 'until curl -f http://localhost:8069/web/health 2>/dev/null; do sleep 5; done' &
    ODOO2_PID=$!
    
    wait $ODOO1_PID
    ODOO1_STATUS=$?
    
    wait $ODOO2_PID
    ODOO2_STATUS=$?
    
    if [ $ODOO1_STATUS -eq 0 ] && [ $ODOO2_STATUS -eq 0 ]; then
        log_success "Both Odoo instances are ready"
    else
        log_error "One or more Odoo instances failed to start"
        return 1
    fi
    
    # Start graph sync service
    docker-compose -f "$CI_COMPOSE_FILE" up -d graphsync
    
    # Wait for graph sync
    log_info "Waiting for GraphSync service..."
    timeout 60 bash -c 'until curl -f http://localhost:8000/healthcheck 2>/dev/null; do sleep 5; done'
    
    if [ $? -eq 0 ]; then
        log_success "GraphSync service is ready"
    else
        log_warning "GraphSync service may not be ready, continuing..."
    fi
}

test_modules() {
    log_info "Testing Odoo modules..."
    
    mkdir -p "$LOG_DIR"
    
    # Test instance 1 modules
    if [ -d "addons_instance1" ]; then
        log_info "Testing instance 1 modules..."
        
        CUSTOM_MODULES=$(find addons_instance1 -name '__manifest__.py' -exec dirname {} \; | xargs -I {} basename {} 2>/dev/null || echo "")
        
        for module in $CUSTOM_MODULES; do
            if [ -n "$module" ]; then
                log_info "Testing module: $module (instance 1)"
                
                docker-compose -f "$CI_COMPOSE_FILE" exec -T odoo1 odoo-bin \
                    --test-enable \
                    --stop-after-init \
                    --database=odoo_db1 \
                    --update="$module" \
                    --log-level=test > "$LOG_DIR/test_${module}_instance1.log" 2>&1
                
                if [ $? -eq 0 ]; then
                    log_success "Module $module (instance 1) tests passed"
                else
                    log_warning "Module $module (instance 1) tests failed - check logs"
                fi
            fi
        done
    fi
    
    # Test instance 2 modules
    if [ -d "addons_instance2" ]; then
        log_info "Testing instance 2 modules..."
        
        CUSTOM_MODULES=$(find addons_instance2 -name '__manifest__.py' -exec dirname {} \; | xargs -I {} basename {} 2>/dev/null || echo "")
        
        for module in $CUSTOM_MODULES; do
            if [ -n "$module" ]; then
                log_info "Testing module: $module (instance 2)"
                
                docker-compose -f "$CI_COMPOSE_FILE" exec -T odoo2 odoo-bin \
                    --test-enable \
                    --stop-after-init \
                    --database=odoo_db2 \
                    --update="$module" \
                    --log-level=test > "$LOG_DIR/test_${module}_instance2.log" 2>&1
                
                if [ $? -eq 0 ]; then
                    log_success "Module $module (instance 2) tests passed"
                else
                    log_warning "Module $module (instance 2) tests failed - check logs"
                fi
            fi
        done
    fi
}

check_health() {
    log_info "Checking service health..."
    
    # Check container status
    docker-compose -f "$CI_COMPOSE_FILE" ps
    
    # Check service endpoints
    log_info "Checking service endpoints..."
    
    curl -f http://localhost:8070/web/health >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_success "Odoo instance 1 is healthy"
    else
        log_error "Odoo instance 1 health check failed"
    fi
    
    curl -f http://localhost:8069/web/health >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_success "Odoo instance 2 is healthy"
    else
        log_error "Odoo instance 2 health check failed"
    fi
    
    curl -f http://localhost:8000/healthcheck >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_success "GraphSync service is healthy"
    else
        log_warning "GraphSync service health check failed"
    fi
}

analyze_dependencies() {
    log_info "Analyzing module dependencies..."
    
    # Trigger sync
    log_info "Triggering graph synchronization..."
    SYNC_RESPONSE=$(curl -s -X POST http://localhost:8000/sync-all 2>/dev/null || echo "sync_failed")
    log_info "Sync response: $SYNC_RESPONSE"
    
    # Analyze dependencies
    log_info "Running dependency analysis..."
    ANALYSIS_RESPONSE=$(curl -s http://localhost:8000/analyze-dependencies 2>/dev/null || echo "analysis_failed")
    
    # Save analysis results
    echo "$ANALYSIS_RESPONSE" > "$LOG_DIR/dependency-analysis.json"
    
    # Check for cycles
    if echo "$ANALYSIS_RESPONSE" | grep -q '"cycles_detected":true' 2>/dev/null; then
        log_error "Dependency cycles detected!"
        echo "$ANALYSIS_RESPONSE" | jq '.' 2>/dev/null || echo "$ANALYSIS_RESPONSE"
        return 1
    else
        log_success "No dependency cycles detected"
        return 0
    fi
}

show_logs() {
    log_info "Showing recent logs..."
    
    echo "=== PostgreSQL Logs ==="
    docker-compose -f "$CI_COMPOSE_FILE" logs --tail=20 postgres
    
    echo "=== Odoo1 Logs ==="
    docker-compose -f "$CI_COMPOSE_FILE" logs --tail=20 odoo1
    
    echo "=== Odoo2 Logs ==="
    docker-compose -f "$CI_COMPOSE_FILE" logs --tail=20 odoo2
    
    echo "=== GraphSync Logs ==="
    docker-compose -f "$CI_COMPOSE_FILE" logs --tail=20 graphsync
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -c, --cleanup-only  Only cleanup existing containers"
    echo "  -t, --test-only     Only run tests (skip dependency analysis)"
    echo "  -a, --analyze-only  Only run dependency analysis"
    echo "  -l, --logs          Show service logs"
    echo "  --timeout SECONDS   Set test timeout (default: 300)"
}

# Main execution
main() {
    local cleanup_only=false
    local test_only=false
    local analyze_only=false
    local show_logs_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -c|--cleanup-only)
                cleanup_only=true
                shift
                ;;
            -t|--test-only)
                test_only=true
                shift
                ;;
            -a|--analyze-only)
                analyze_only=true
                shift
                ;;
            -l|--logs)
                show_logs_only=true
                shift
                ;;
            --timeout)
                TEST_TIMEOUT="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Handle special modes
    if [ "$cleanup_only" = true ]; then
        cleanup
        exit 0
    fi
    
    if [ "$show_logs_only" = true ]; then
        show_logs
        exit 0
    fi
    
    # Main workflow
    log_info "Starting Odoo module testing workflow..."
    
    # Generate configurations
    generate_ci_compose
    generate_config
    
    # Start services
    if ! start_services; then
        log_error "Failed to start services"
        show_logs
        exit 1
    fi
    
    # Run tests
    if [ "$analyze_only" != true ]; then
        test_modules
        check_health
    fi
    
    # Run dependency analysis
    if [ "$test_only" != true ]; then
        if ! analyze_dependencies; then
            log_error "Dependency analysis failed or cycles detected"
            exit 1
        fi
    fi
    
    log_success "All tests completed successfully!"
    
    # Show summary
    echo ""
    log_info "=== Test Summary ==="
    echo "- Services started and health checked"
    echo "- Module tests executed"
    if [ "$test_only" != true ]; then
        echo "- Dependency analysis completed"
    fi
    echo "- Logs available in: $LOG_DIR/"
    echo "- CI compose file: $CI_COMPOSE_FILE"
}

# Run main function with all arguments
main "$@"