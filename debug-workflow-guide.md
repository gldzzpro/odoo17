# GitHub Actions Workflow Debugging Guide

This guide provides a comprehensive approach to debugging and improving your Odoo CI/CD workflow.

## 1. Lint & Validate

### Install actionlint
```bash
# Install actionlint (GitHub Actions linter)
# On macOS
brew install actionlint

# On Linux
curl -s https://api.github.com/repos/rhysd/actionlint/releases/latest | \
  grep "browser_download_url.*linux_amd64.tar.gz" | \
  cut -d : -f 2,3 | tr -d \" | \
  xargs curl -L | tar -xz actionlint
sudo mv actionlint /usr/local/bin/

# On Windows (using chocolatey)
choco install actionlint
```

### Run YAML Linting
```bash
# Lint the workflow file
actionlint .github/workflows/simple-odoo-ci.yml

# Lint with verbose output
actionlint -verbose .github/workflows/simple-odoo-ci.yml

# Lint all workflow files
actionlint .github/workflows/

# Check for specific issues
actionlint -format '{{range $err := .}}::error file={{$err.Filepath}},line={{$err.Line}},col={{$err.Column}}::{{$err.Message}}{{end}}' .github/workflows/
```

### Common Issues and Fixes

#### 1. Deprecated Actions
```yaml
# ❌ Bad - Using outdated versions
uses: actions/checkout@v2
uses: actions/setup-node@v2

# ✅ Good - Using current stable versions
uses: actions/checkout@v4
uses: actions/setup-node@v4
```

#### 2. Expression Syntax Errors
```yaml
# ❌ Bad - Missing quotes around expressions with special characters
run: echo ${{ github.ref_name }}

# ✅ Good - Properly quoted
run: echo "${{ github.ref_name }}"
```

#### 3. Health Check Syntax
```yaml
# ❌ Bad - Incorrect healthcheck format
healthcheck:
  test: pg_isready -U odoo

# ✅ Good - Proper array format
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U odoo"]
```

## 2. Local Emulation with act

### Install act
```bash
# On macOS
brew install act

# On Linux
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# On Windows (using chocolatey)
choco install act-cli
```

### Basic act Usage
```bash
# List all jobs
act -l

# Run specific job
act -j setup

# Run on push event
act push

# Run with specific event data
act push --eventpath .github/workflows/test-event.json

# Run with secrets
act -s GITHUB_TOKEN=your_token

# Run with custom runner image
act -P ubuntu-latest=catthehacker/ubuntu:act-latest

# Dry run (show what would be executed)
act --dryrun

# Run with verbose output
act -v
```

### Create Test Event File
```bash
# Create test event for push
cat > .github/workflows/test-event.json << 'EOF'
{
  "ref": "refs/heads/branch-a",
  "repository": {
    "name": "odoo17",
    "full_name": "your-username/odoo17"
  },
  "pusher": {
    "name": "test-user"
  },
  "head_commit": {
    "id": "test-commit-sha",
    "message": "Test commit"
  }
}
EOF
```

### act Configuration
```bash
# Create .actrc file for default settings
cat > .actrc << 'EOF'
-P ubuntu-latest=catthehacker/ubuntu:act-latest
--container-daemon-socket /var/run/docker.sock
--reuse
EOF
```

## 3. Incremental Debugging

### Debug Script for Environment Inspection
```bash
#!/bin/bash
# debug-env.sh - Add this to any job for debugging

echo "=== Environment Variables ==="
printenv | sort

echo "=== Current Directory ==="
pwd
ls -la

echo "=== Git Status ==="
git status || echo "Not a git repository"
git log --oneline -5 || echo "No git history"

echo "=== Docker Info ==="
docker --version
docker-compose --version
docker ps
docker images

echo "=== System Resources ==="
df -h
free -h
nproc

echo "=== Network ==="
ip addr show || ifconfig
netstat -tuln | head -20
```

### Isolate Failing Jobs
```yaml
# Add debug steps at the beginning of each job
- name: Debug Environment
  run: |
    echo "=== Job Debug Info ==="
    printenv | sort
    ls -R . | head -50
    docker ps
    docker images

# Use conditional execution to isolate issues
- name: Potentially Failing Step
  if: always()  # Run even if previous steps failed
  continue-on-error: true  # Don't fail the job if this step fails
  run: |
    # Your potentially failing command
    echo "This step might fail but won't stop the workflow"

# Temporarily disable downstream jobs
job2:
  needs: job1
  if: false  # Temporarily disable this job
  runs-on: ubuntu-latest
```

### Step-by-Step Replacement Strategy
```yaml
# Replace complex steps with simple echo commands first
- name: Test Step Structure
  run: |
    echo "Step 1: This would normally do complex task A"
    echo "Step 2: This would normally do complex task B"
    echo "Step 3: This would normally do complex task C"
    # Original complex commands commented out:
    # docker-compose up -d
    # wait_for_services.sh
    # run_tests.sh
```

## 4. Common Pitfalls & Fixes

### Docker Compose Issues
```yaml
# ❌ Bad - Missing version and improper healthcheck
services:
  postgres:
    image: postgres:15
    healthcheck:
      test: pg_isready

# ✅ Good - Proper format with all required fields
version: '3.8'
services:
  postgres:
    image: postgres:15-alpine
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
```

### Secret Management
```yaml
# ❌ Bad - Hardcoded secrets
run: |
  curl -H "Authorization: Bearer sk-1234567890" https://api.example.com

# ✅ Good - Using GitHub secrets
run: |
  curl -H "Authorization: Bearer ${{ secrets.API_TOKEN }}" https://api.example.com
env:
  API_TOKEN: ${{ secrets.API_TOKEN }}
```

### Timeout Protection
```yaml
# Add timeouts to prevent hanging
- name: Wait for Service
  timeout-minutes: 5
  run: |
    timeout 300 bash -c 'while ! curl -f http://localhost:8069/health; do sleep 5; done'
```

## 5. Version Locking

### Recommended Action Versions
```yaml
# Core actions
uses: actions/checkout@v4
uses: actions/setup-node@v4
uses: actions/setup-python@v4
uses: actions/cache@v3
uses: actions/upload-artifact@v4
uses: actions/download-artifact@v4

# Docker actions
uses: docker/setup-buildx-action@v3
uses: docker/build-push-action@v5
uses: docker/login-action@v3

# Third-party actions (pin to specific commits for security)
uses: dorny/paths-filter@v2.11.1
uses: 8398a7/action-slack@v3.15.0
```

### Version Pinning Script
```bash
#!/bin/bash
# pin-action-versions.sh

# Update all action versions in workflow files
find .github/workflows -name "*.yml" -o -name "*.yaml" | while read file; do
  echo "Updating $file"
  
  # Update common actions to latest stable versions
  sed -i.bak 's/actions\/checkout@v[0-9]*/actions\/checkout@v4/g' "$file"
  sed -i.bak 's/actions\/setup-node@v[0-9]*/actions\/setup-node@v4/g' "$file"
  sed -i.bak 's/actions\/setup-python@v[0-9]*/actions\/setup-python@v4/g' "$file"
  sed -i.bak 's/actions\/cache@v[0-9]*/actions\/cache@v3/g' "$file"
  sed -i.bak 's/actions\/upload-artifact@v[0-9]*/actions\/upload-artifact@v4/g' "$file"
  sed -i.bak 's/actions\/download-artifact@v[0-9]*/actions\/download-artifact@v4/g' "$file"
  
  # Remove backup files
  rm "$file.bak"
done
```

## 6. Iterative Testing Strategy

### Testing Workflow
```bash
#!/bin/bash
# test-workflow.sh - Iterative testing script

set -e

echo "=== Phase 1: Syntax Validation ==="
actionlint .github/workflows/simple-odoo-ci-improved.yml

echo "=== Phase 2: Local Dry Run ==="
act --dryrun -j setup

echo "=== Phase 3: Simple Test ==="
# Create a minimal test version
cp .github/workflows/simple-odoo-ci-improved.yml .github/workflows/test-minimal.yml

# Replace complex steps with echo commands
sed -i.bak 's/docker-compose.*up.*/echo "Would start docker-compose"/g' .github/workflows/test-minimal.yml
sed -i.bak 's/timeout.*bash.*/echo "Would wait for services"/g' .github/workflows/test-minimal.yml

echo "=== Phase 4: Run Minimal Test ==="
act -j setup -W .github/workflows/test-minimal.yml

echo "=== Phase 5: Gradual Complexity ==="
echo "Now gradually add back complex steps one by one"

# Cleanup
rm .github/workflows/test-minimal.yml*
```

### Timeout Wrapper Script
```bash
#!/bin/bash
# timeout-wrapper.sh - Wrap commands with timeout protection

TIMEOUT=${1:-300}  # Default 5 minutes
shift
COMMAND="$@"

echo "Running with timeout: $TIMEOUT seconds"
echo "Command: $COMMAND"

timeout $TIMEOUT bash -c "$COMMAND" || {
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 124 ]; then
    echo "❌ Command timed out after $TIMEOUT seconds"
  else
    echo "❌ Command failed with exit code $EXIT_CODE"
  fi
  exit $EXIT_CODE
}

echo "✅ Command completed successfully"
```

## 7. Final Validation

### Complete Validation Script
```bash
#!/bin/bash
# validate-workflow.sh - Complete workflow validation

set -e

WORKFLOW_FILE=".github/workflows/simple-odoo-ci-improved.yml"

echo "🔍 Starting workflow validation..."

echo "=== Step 1: YAML Syntax Check ==="
yamllint $WORKFLOW_FILE || echo "yamllint not installed, skipping"

echo "=== Step 2: GitHub Actions Linting ==="
actionlint $WORKFLOW_FILE

echo "=== Step 3: Security Scan ==="
# Check for hardcoded secrets
if grep -r "sk-\|ghp_\|gho_\|ghu_\|ghs_" $WORKFLOW_FILE; then
  echo "❌ Potential hardcoded secrets found!"
  exit 1
else
  echo "✅ No hardcoded secrets detected"
fi

echo "=== Step 4: Local Test with act ==="
act --dryrun -j setup

echo "=== Step 5: Docker Compose Validation ==="
if [ -f "docker-compose.simple.yml" ]; then
  docker-compose -f docker-compose.simple.yml config
else
  echo "Docker compose file will be generated during workflow"
fi

echo "=== Step 6: Script Permissions Check ==="
find scripts/ -name "*.sh" -exec test -x {} \; -print || {
  echo "Making scripts executable..."
  chmod +x scripts/*.sh
}

echo "✅ All validations passed!"
echo "🚀 Workflow is ready for deployment"
```

### Monitoring Script
```bash
#!/bin/bash
# monitor-workflow.sh - Monitor running workflow

WORKFLOW_RUN_ID="$1"

if [ -z "$WORKFLOW_RUN_ID" ]; then
  echo "Usage: $0 <workflow_run_id>"
  echo "Get run ID from: gh run list"
  exit 1
fi

echo "Monitoring workflow run: $WORKFLOW_RUN_ID"

while true; do
  STATUS=$(gh run view $WORKFLOW_RUN_ID --json status -q '.status')
  echo "$(date): Status = $STATUS"
  
  if [ "$STATUS" = "completed" ]; then
    CONCLUSION=$(gh run view $WORKFLOW_RUN_ID --json conclusion -q '.conclusion')
    echo "Workflow completed with conclusion: $CONCLUSION"
    
    if [ "$CONCLUSION" = "failure" ]; then
      echo "Fetching failure logs..."
      gh run view $WORKFLOW_RUN_ID --log-failed
    fi
    break
  fi
  
  sleep 30
done
```

## Usage Examples

### Quick Start
```bash
# 1. Validate workflow
./validate-workflow.sh

# 2. Test locally
act -j setup --dryrun

# 3. Run with debugging
act -j setup -v

# 4. Monitor real run
gh workflow run simple-odoo-ci-improved.yml
gh run list
./monitor-workflow.sh <run_id>
```

### Troubleshooting Checklist

1. **Syntax Issues**
   - Run `actionlint` on all workflow files
   - Check YAML indentation and quotes
   - Validate Docker Compose syntax

2. **Permission Issues**
   - Ensure scripts are executable: `chmod +x scripts/*.sh`
   - Check GitHub token permissions
   - Verify Docker daemon access

3. **Timeout Issues**
   - Add timeout protection to long-running steps
   - Increase job timeout if needed
   - Check for infinite loops in wait conditions

4. **Resource Issues**
   - Monitor disk space and memory usage
   - Clean up Docker resources between runs
   - Use smaller base images when possible

5. **Network Issues**
   - Check service health checks
   - Verify port mappings
   - Test connectivity between services

This guide provides a comprehensive approach to debugging and improving your GitHub Actions workflow. Follow the steps systematically to identify and resolve issues.