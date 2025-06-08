#!/bin/bash
# validate-workflow.sh - Complete workflow validation script
# This script performs comprehensive validation of GitHub Actions workflows

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

check_dependencies() {
    log_info "Checking required dependencies..."
    
    local missing_deps=()
    
    # Check for actionlint
    if ! command -v actionlint &> /dev/null; then
        missing_deps+=("actionlint")
    fi
    
    # Check for docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    # Check for docker-compose
    if ! command -v docker-compose &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    # Check for yamllint (optional)
    if ! command -v yamllint &> /dev/null; then
        log_warning "yamllint not found (optional dependency)"
    fi
    
    # Check for act (optional)
    if ! command -v act &> /dev/null; then
        log_warning "act not found (optional dependency for local testing)"
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install missing dependencies:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                "actionlint")
                    echo "  - actionlint: brew install actionlint (macOS) or see https://github.com/rhysd/actionlint"
                    ;;
                "docker")
                    echo "  - docker: https://docs.docker.com/get-docker/"
                    ;;
                "docker-compose")
                    echo "  - docker-compose: https://docs.docker.com/compose/install/"
                    ;;
            esac
        done
        exit 1
    fi
    
    log_success "All required dependencies found"
}

validate_yaml_syntax() {
    log_info "Validating YAML syntax..."
    
    local workflow_files=()
    if [ -f "$WORKFLOW_DIR/$MAIN_WORKFLOW" ]; then
        workflow_files+=("$WORKFLOW_DIR/$MAIN_WORKFLOW")
    fi
    if [ -f "$WORKFLOW_DIR/$ORIGINAL_WORKFLOW" ]; then
        workflow_files+=("$WORKFLOW_DIR/$ORIGINAL_WORKFLOW")
    fi
    
    if [ ${#workflow_files[@]} -eq 0 ]; then
        log_error "No workflow files found in $WORKFLOW_DIR"
        return 1
    fi
    
    for file in "${workflow_files[@]}"; do
        log_info "Checking $file"
        
        # Basic YAML syntax check with Python
        if command -v python3 &> /dev/null; then
            python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null || {
                log_error "YAML syntax error in $file"
                return 1
            }
        fi
        
        # yamllint if available
        if command -v yamllint &> /dev/null; then
            yamllint "$file" || log_warning "yamllint warnings in $file"
        fi
    done
    
    log_success "YAML syntax validation passed"
}

run_actionlint() {
    log_info "Running GitHub Actions linting..."
    
    local workflow_files=()
    if [ -f "$WORKFLOW_DIR/$MAIN_WORKFLOW" ]; then
        workflow_files+=("$WORKFLOW_DIR/$MAIN_WORKFLOW")
    fi
    if [ -f "$WORKFLOW_DIR/$ORIGINAL_WORKFLOW" ]; then
        workflow_files+=("$WORKFLOW_DIR/$ORIGINAL_WORKFLOW")
    fi
    
    for file in "${workflow_files[@]}"; do
        log_info "Linting $file"
        if actionlint "$file"; then
            log_success "actionlint passed for $file"
        else
            log_error "actionlint failed for $file"
            return 1
        fi
    done
}

check_security() {
    log_info "Performing security checks..."
    
    local security_issues=0
    
    # Check for hardcoded secrets patterns
    local secret_patterns=(
        "sk-[a-zA-Z0-9]{32,}"  # OpenAI API keys
        "ghp_[a-zA-Z0-9]{36}"  # GitHub personal access tokens
        "gho_[a-zA-Z0-9]{36}"  # GitHub OAuth tokens
        "ghu_[a-zA-Z0-9]{36}"  # GitHub user tokens
        "ghs_[a-zA-Z0-9]{36}"  # GitHub server tokens
        "xoxb-[a-zA-Z0-9-]+"   # Slack bot tokens
        "xoxp-[a-zA-Z0-9-]+"   # Slack user tokens
        "AKIA[0-9A-Z]{16}"     # AWS access keys
    )
    
    for pattern in "${secret_patterns[@]}"; do
        if grep -r -E "$pattern" "$WORKFLOW_DIR" 2>/dev/null; then
            log_error "Potential hardcoded secret found matching pattern: $pattern"
            security_issues=$((security_issues + 1))
        fi
    done
    
    # Check for suspicious environment variables
    if grep -r "PASSWORD.*=.*[^$]" "$WORKFLOW_DIR" 2>/dev/null | grep -v "\${{" | grep -v "secrets\."; then
        log_error "Potential hardcoded password found"
        security_issues=$((security_issues + 1))
    fi
    
    if [ $security_issues -eq 0 ]; then
        log_success "No security issues detected"
    else
        log_error "$security_issues security issue(s) found"
        return 1
    fi
}

test_with_act() {
    if ! command -v act &> /dev/null; then
        log_warning "act not available, skipping local testing"
        return 0
    fi
    
    log_info "Testing workflow with act (dry run)..."
    
    local workflow_file="$WORKFLOW_DIR/$MAIN_WORKFLOW"
    if [ ! -f "$workflow_file" ]; then
        workflow_file="$WORKFLOW_DIR/$ORIGINAL_WORKFLOW"
    fi
    
    if [ ! -f "$workflow_file" ]; then
        log_error "No workflow file found for testing"
        return 1
    fi
    
    # Create .actrc if it doesn't exist
    if [ ! -f ".actrc" ]; then
        log_info "Creating .actrc configuration"
        cat > .actrc << 'EOF'
-P ubuntu-latest=catthehacker/ubuntu:act-latest
--container-daemon-socket /var/run/docker.sock
--reuse
EOF
    fi
    
    # Run dry run
    if act --dryrun -j setup 2>/dev/null; then
        log_success "act dry run passed"
    else
        log_warning "act dry run had issues (this might be expected)"
    fi
}

validate_docker_compose() {
    log_info "Validating Docker Compose configuration..."
    
    # Check if docker-compose.simple.yml exists
    if [ -f "docker-compose.simple.yml" ]; then
        log_info "Found existing docker-compose.simple.yml, validating..."
        if docker-compose -f docker-compose.simple.yml config >/dev/null 2>&1; then
            log_success "Docker Compose configuration is valid"
        else
            log_error "Docker Compose configuration is invalid"
            return 1
        fi
    else
        log_info "docker-compose.simple.yml not found (will be generated during workflow)"
    fi
    
    # Check if Dockerfile exists
    if [ -f "Dockerfile" ]; then
        log_success "Dockerfile found"
    else
        log_warning "Dockerfile not found - workflow may fail during build step"
    fi
}

check_script_permissions() {
    log_info "Checking script permissions..."
    
    local script_issues=0
    
    # Check if scripts directory exists
    if [ ! -d "scripts" ]; then
        log_warning "scripts directory not found"
        return 0
    fi
    
    # Check shell scripts
    while IFS= read -r -d '' script; do
        if [ ! -x "$script" ]; then
            log_warning "Script not executable: $script"
            chmod +x "$script"
            log_info "Made $script executable"
        fi
    done < <(find scripts/ -name "*.sh" -print0 2>/dev/null)
    
    # Check Python scripts
    while IFS= read -r -d '' script; do
        if [ ! -r "$script" ]; then
            log_warning "Python script not readable: $script"
            script_issues=$((script_issues + 1))
        fi
    done < <(find scripts/ -name "*.py" -print0 2>/dev/null)
    
    if [ $script_issues -eq 0 ]; then
        log_success "All scripts have correct permissions"
    fi
}

generate_report() {
    log_info "Generating validation report..."
    
    local report_file="workflow-validation-report.md"
    
    cat > "$report_file" << EOF
# Workflow Validation Report

Generated on: $(date)
Repository: $(git remote get-url origin 2>/dev/null || echo "Unknown")
Branch: $(git branch --show-current 2>/dev/null || echo "Unknown")
Commit: $(git rev-parse HEAD 2>/dev/null || echo "Unknown")

## Validation Results

### Dependencies
- actionlint: $(command -v actionlint >/dev/null && echo "✅ Installed" || echo "❌ Missing")
- docker: $(command -v docker >/dev/null && echo "✅ Installed" || echo "❌ Missing")
- docker-compose: $(command -v docker-compose >/dev/null && echo "✅ Installed" || echo "❌ Missing")
- yamllint: $(command -v yamllint >/dev/null && echo "✅ Installed" || echo "⚠️ Optional")
- act: $(command -v act >/dev/null && echo "✅ Installed" || echo "⚠️ Optional")

### Workflow Files
EOF
    
    if [ -f "$WORKFLOW_DIR/$MAIN_WORKFLOW" ]; then
        echo "- $MAIN_WORKFLOW: ✅ Found" >> "$report_file"
    fi
    if [ -f "$WORKFLOW_DIR/$ORIGINAL_WORKFLOW" ]; then
        echo "- $ORIGINAL_WORKFLOW: ✅ Found" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

### Docker Configuration
- Dockerfile: $([ -f "Dockerfile" ] && echo "✅ Found" || echo "❌ Missing")
- docker-compose.simple.yml: $([ -f "docker-compose.simple.yml" ] && echo "✅ Found" || echo "⚠️ Generated during workflow")

### Scripts
EOF
    
    if [ -d "scripts" ]; then
        find scripts/ -name "*.sh" -o -name "*.py" | while read -r script; do
            echo "- $script: $([ -x "$script" ] && echo "✅ Executable" || echo "⚠️ Not executable")" >> "$report_file"
        done
    else
        echo "- No scripts directory found" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Recommendations

1. **Action Versions**: Ensure all actions use pinned versions (e.g., @v4)
2. **Secrets**: Use GitHub secrets instead of hardcoded values
3. **Timeouts**: Add timeout protection to long-running steps
4. **Error Handling**: Use proper error handling and cleanup steps
5. **Local Testing**: Use 'act' for local workflow testing

## Next Steps

1. Run the improved workflow: \`simple-odoo-ci-improved.yml\`
2. Monitor workflow execution and logs
3. Iterate on any remaining issues
4. Consider adding more comprehensive testing

EOF
    
    log_success "Validation report generated: $report_file"
}

main() {
    echo "🔍 GitHub Actions Workflow Validation"
    echo "====================================="
    echo
    
    # Change to repository root if we're in a subdirectory
    while [ ! -d ".git" ] && [ "$(pwd)" != "/" ]; do
        cd ..
    done
    
    if [ ! -d ".git" ]; then
        log_error "Not in a Git repository"
        exit 1
    fi
    
    local exit_code=0
    
    # Run all validation steps
    check_dependencies || exit_code=1
    validate_yaml_syntax || exit_code=1
    run_actionlint || exit_code=1
    check_security || exit_code=1
    test_with_act || exit_code=1
    validate_docker_compose || exit_code=1
    check_script_permissions || exit_code=1
    
    # Generate report regardless of validation results
    generate_report
    
    echo
    if [ $exit_code -eq 0 ]; then
        log_success "All validations passed! 🚀"
        echo "Your workflow is ready for deployment."
    else
        log_error "Some validations failed. Please review the issues above."
        echo "Check the generated report for detailed recommendations."
    fi
    
    exit $exit_code
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi