#!/bin/bash
# test-with-act.sh - Local GitHub Actions testing with act
# This script helps test workflows locally using nektos/act

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WORKFLOW_DIR=".github/workflows"
MAIN_WORKFLOW="simple-odoo-ci-improved.yml"
ORIGINAL_WORKFLOW="simple-odoo-ci.yml"
ACT_CONFIG=".actrc"
SECRETS_FILE=".secrets"

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_act_installation() {
    log_info "Checking act installation..."
    
    if ! command -v act &> /dev/null; then
        log_error "act is not installed"
        echo "Please install act:"
        echo "  macOS: brew install act"
        echo "  Linux: curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash"
        echo "  Windows: choco install act-cli"
        echo "  Or download from: https://github.com/nektos/act/releases"
        exit 1
    fi
    
    local act_version
    act_version=$(act --version 2>/dev/null | head -n1 || echo "unknown")
    log_success "act is installed: $act_version"
}

setup_act_config() {
    log_info "Setting up act configuration..."
    
    if [ ! -f "$ACT_CONFIG" ]; then
        log_info "Creating $ACT_CONFIG"
        cat > "$ACT_CONFIG" << 'EOF'
# act configuration file
# Use GitHub-compatible runner images
-P ubuntu-latest=catthehacker/ubuntu:act-latest
-P ubuntu-22.04=catthehacker/ubuntu:act-22.04
-P ubuntu-20.04=catthehacker/ubuntu:act-20.04

# Docker daemon socket
--container-daemon-socket /var/run/docker.sock

# Reuse containers for faster subsequent runs
--reuse

# Bind workspace to container
--bind

# Use host network for better connectivity
--use-gitignore=false
EOF
        log_success "Created $ACT_CONFIG"
    else
        log_info "$ACT_CONFIG already exists"
    fi
}

setup_secrets_file() {
    log_info "Setting up secrets file..."
    
    if [ ! -f "$SECRETS_FILE" ]; then
        log_info "Creating $SECRETS_FILE template"
        cat > "$SECRETS_FILE" << 'EOF'
# GitHub Actions secrets for local testing
# Add your secrets here in KEY=VALUE format
# This file should be added to .gitignore

# Example secrets (replace with actual values):
# GITHUB_TOKEN=ghp_your_token_here
# DOCKER_USERNAME=your_docker_username
# DOCKER_PASSWORD=your_docker_password
# FORMSPREE_ENDPOINT=https://formspree.io/f/your_form_id
# SENDGRID_API_KEY=SG.your_sendgrid_key
# EMAIL_TO=your-email@example.com
# EMAIL_FROM=noreply@example.com
EOF
        
        # Add to .gitignore if not already there
        if [ -f ".gitignore" ] && ! grep -q "^.secrets$" .gitignore; then
            echo ".secrets" >> .gitignore
            log_info "Added .secrets to .gitignore"
        fi
        
        log_warning "Created $SECRETS_FILE template - please add your actual secrets"
        log_warning "Remember to add real values before running tests that require secrets"
    else
        log_info "$SECRETS_FILE already exists"
    fi
}

list_workflows() {
    log_info "Available workflows:"
    
    local count=0
    if [ -d "$WORKFLOW_DIR" ]; then
        for workflow in "$WORKFLOW_DIR"/*.yml "$WORKFLOW_DIR"/*.yaml; do
            if [ -f "$workflow" ]; then
                local basename_workflow
                basename_workflow=$(basename "$workflow")
                echo "  - $basename_workflow"
                count=$((count + 1))
            fi
        done
    fi
    
    if [ $count -eq 0 ]; then
        log_warning "No workflow files found in $WORKFLOW_DIR"
        return 1
    fi
    
    log_success "Found $count workflow file(s)"
}

list_jobs() {
    local workflow_file="$1"
    
    if [ ! -f "$workflow_file" ]; then
        log_error "Workflow file not found: $workflow_file"
        return 1
    fi
    
    log_info "Jobs in $(basename "$workflow_file"):"
    
    # Extract job names using grep and awk
    if command -v yq &> /dev/null; then
        # Use yq if available for better YAML parsing
        yq eval '.jobs | keys | .[]' "$workflow_file" 2>/dev/null | while read -r job; do
            echo "  - $job"
        done
    else
        # Fallback to grep/awk
        grep -E '^[[:space:]]*[a-zA-Z0-9_-]+:' "$workflow_file" | \
            grep -A1 -B1 'runs-on:' | \
            grep -E '^[[:space:]]*[a-zA-Z0-9_-]+:' | \
            awk -F: '{gsub(/^[[:space:]]+/, "", $1); print "  - " $1}'
    fi
}

run_dry_run() {
    local workflow_file="$1"
    local job_name="$2"
    
    log_info "Running dry run for workflow: $(basename "$workflow_file")"
    
    local act_cmd="act --dryrun"
    
    if [ -n "$job_name" ]; then
        act_cmd="$act_cmd -j $job_name"
        log_info "Targeting job: $job_name"
    fi
    
    if [ -f "$SECRETS_FILE" ]; then
        act_cmd="$act_cmd --secret-file $SECRETS_FILE"
    fi
    
    log_info "Running: $act_cmd"
    
    if eval "$act_cmd"; then
        log_success "Dry run completed successfully"
    else
        log_error "Dry run failed"
        return 1
    fi
}

run_workflow() {
    local workflow_file="$1"
    local job_name="$2"
    local event="${3:-push}"
    
    log_info "Running workflow: $(basename "$workflow_file")"
    log_warning "This will execute the actual workflow steps!"
    
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled by user"
        return 0
    fi
    
    local act_cmd="act $event"
    
    if [ -n "$job_name" ]; then
        act_cmd="$act_cmd -j $job_name"
        log_info "Targeting job: $job_name"
    fi
    
    if [ -f "$SECRETS_FILE" ]; then
        act_cmd="$act_cmd --secret-file $SECRETS_FILE"
    fi
    
    # Add verbose output for debugging
    act_cmd="$act_cmd --verbose"
    
    log_info "Running: $act_cmd"
    
    if eval "$act_cmd"; then
        log_success "Workflow completed successfully"
    else
        log_error "Workflow failed"
        return 1
    fi
}

run_specific_step() {
    local workflow_file="$1"
    local job_name="$2"
    local step_name="$3"
    
    log_info "Running specific step: $step_name in job: $job_name"
    
    # This is a simplified approach - act doesn't support running individual steps
    # Instead, we'll create a temporary workflow with just that step
    
    local temp_workflow=".github/workflows/temp-single-step.yml"
    
    log_info "Creating temporary workflow for single step testing"
    
    cat > "$temp_workflow" << EOF
name: Single Step Test
on: [push]
jobs:
  test-step:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: $step_name
        run: |
          echo "Testing single step: $step_name"
          # Add your step commands here
EOF
    
    log_warning "Please manually edit $temp_workflow to add the specific step commands"
    log_info "Then run: act -j test-step"
}

cleanup_act() {
    log_info "Cleaning up act containers and images..."
    
    # Stop and remove act containers
    docker ps -a --filter "label=act" --format "{{.ID}}" | xargs -r docker rm -f
    
    # Remove act networks
    docker network ls --filter "name=act" --format "{{.ID}}" | xargs -r docker network rm
    
    # Optionally remove act images (commented out to avoid re-downloading)
    # docker images --filter "reference=catthehacker/ubuntu" --format "{{.ID}}" | xargs -r docker rmi
    
    log_success "Cleanup completed"
}

show_help() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Commands:
  setup           Set up act configuration and secrets template
  list            List available workflows and jobs
  dry-run         Run workflow in dry-run mode (no execution)
  run             Run workflow locally (with confirmation)
  step            Run a specific step (creates temporary workflow)
  cleanup         Clean up act containers and networks
  help            Show this help message

Options:
  -w, --workflow  Specify workflow file (default: $MAIN_WORKFLOW)
  -j, --job       Specify job name to run
  -e, --event     Specify event type (default: push)
  -s, --step      Specify step name (for step command)

Examples:
  $0 setup                                    # Set up act configuration
  $0 list                                     # List all workflows and jobs
  $0 dry-run                                  # Dry run default workflow
  $0 dry-run -w simple-odoo-ci.yml           # Dry run specific workflow
  $0 dry-run -j setup                        # Dry run specific job
  $0 run -j setup                            # Run specific job
  $0 cleanup                                  # Clean up act resources

Notes:
  - Make sure Docker is running before using act
  - Add your secrets to .secrets file for testing
  - Use dry-run first to validate workflow syntax
  - act may not support all GitHub Actions features

EOF
}

main() {
    local command="${1:-help}"
    local workflow_file=""
    local job_name=""
    local event="push"
    local step_name=""
    
    # Parse arguments
    shift || true
    while [[ $# -gt 0 ]]; do
        case $1 in
            -w|--workflow)
                workflow_file="$2"
                shift 2
                ;;
            -j|--job)
                job_name="$2"
                shift 2
                ;;
            -e|--event)
                event="$2"
                shift 2
                ;;
            -s|--step)
                step_name="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Set default workflow file
    if [ -z "$workflow_file" ]; then
        if [ -f "$WORKFLOW_DIR/$MAIN_WORKFLOW" ]; then
            workflow_file="$WORKFLOW_DIR/$MAIN_WORKFLOW"
        elif [ -f "$WORKFLOW_DIR/$ORIGINAL_WORKFLOW" ]; then
            workflow_file="$WORKFLOW_DIR/$ORIGINAL_WORKFLOW"
        else
            log_error "No default workflow file found"
            exit 1
        fi
    else
        # Add workflow directory if not absolute path
        if [[ "$workflow_file" != /* ]] && [[ "$workflow_file" != ./* ]]; then
            workflow_file="$WORKFLOW_DIR/$workflow_file"
        fi
    fi
    
    # Change to repository root
    while [ ! -d ".git" ] && [ "$(pwd)" != "/" ]; do
        cd ..
    done
    
    if [ ! -d ".git" ]; then
        log_error "Not in a Git repository"
        exit 1
    fi
    
    echo "🎭 GitHub Actions Local Testing with act"
    echo "======================================="
    echo
    
    case $command in
        setup)
            check_act_installation
            setup_act_config
            setup_secrets_file
            log_success "Setup completed!"
            echo "Next steps:"
            echo "1. Edit .secrets file with your actual secrets"
            echo "2. Run: $0 list"
            echo "3. Run: $0 dry-run"
            ;;
        list)
            list_workflows
            echo
            if [ -f "$workflow_file" ]; then
                list_jobs "$workflow_file"
            fi
            ;;
        dry-run)
            check_act_installation
            run_dry_run "$workflow_file" "$job_name"
            ;;
        run)
            check_act_installation
            run_workflow "$workflow_file" "$job_name" "$event"
            ;;
        step)
            if [ -z "$step_name" ]; then
                log_error "Step name required for step command"
                echo "Use: $0 step -s 'step-name' -j 'job-name'"
                exit 1
            fi
            run_specific_step "$workflow_file" "$job_name" "$step_name"
            ;;
        cleanup)
            cleanup_act
            ;;
        help)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi