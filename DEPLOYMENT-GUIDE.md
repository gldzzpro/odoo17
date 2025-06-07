# 🚀 Deployment Guide: Odoo Multi-Instance CI/CD

This guide walks you through setting up the complete GitHub Actions workflow for your Odoo multi-instance project.

## 📋 Prerequisites

### Local Environment
- [x] Docker Desktop installed and running
- [x] Git configured with your GitHub account
- [x] Bash shell (macOS/Linux) or WSL (Windows)
- [x] curl command available
- [x] Text editor (VS Code recommended)

### GitHub Repository
- [x] GitHub repository created
- [x] Admin access to repository settings
- [x] Ability to create branches and manage secrets

## 🏗️ Step 1: Repository Setup

### 1.1 Initialize Repository Structure

```bash
# Clone your repository
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO

# Create branch structure
git checkout -b branch-a
git push -u origin branch-a

git checkout -b branch-b
git push -u origin branch-b

git checkout main
```

### 1.2 Copy Project Files

Ensure your repository has the following structure:

```
YOUR_REPO/
├── .github/workflows/odoo-ci-cd.yml
├── scripts/test_docker_modules.sh
├── addons_instance1/
├── addons_instance2/
├── addons/
├── graph_sync/
├── docker-compose.yml
├── Dockerfile
├── entrypoint.sh
├── init-multiple-databases.sh
├── odoo1.conf
├── odoo2.conf
├── README-GITHUB-ACTIONS.md
└── DEPLOYMENT-GUIDE.md
```

## 🔐 Step 2: Configure GitHub Secrets

### 2.1 Access Repository Settings
1. Go to your GitHub repository
2. Click **Settings** tab
3. Navigate to **Secrets and variables** → **Actions**
4. Click **New repository secret**

### 2.2 Required Secrets

Add the following secrets one by one:

#### Slack Notifications (Optional)
```
Name: SLACK_WEBHOOK_URL
Value: https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
```

#### Email Notifications (Optional)
```
Name: SMTP_SERVER
Value: smtp.gmail.com

Name: SMTP_PORT
Value: 587

Name: SMTP_USERNAME
Value: your-email@gmail.com

Name: SMTP_PASSWORD
Value: your-app-password

Name: NOTIFY_EMAIL
Value: team@company.com
```

#### Docker Hub (Optional - for private images)
```
Name: DOCKER_USERNAME
Value: your-dockerhub-username

Name: DOCKER_PASSWORD
Value: your-dockerhub-password
```

### 2.3 Slack Webhook Setup (Optional)

1. Go to [Slack API](https://api.slack.com/apps)
2. Create new app → From scratch
3. Choose workspace and app name
4. Go to **Incoming Webhooks**
5. Activate incoming webhooks
6. Add new webhook to workspace
7. Copy webhook URL to GitHub secrets

### 2.4 Gmail App Password Setup (Optional)

1. Enable 2-factor authentication on Gmail
2. Go to Google Account settings
3. Security → 2-Step Verification → App passwords
4. Generate app password for "Mail"
5. Use generated password in `SMTP_PASSWORD` secret

## 🌿 Step 3: Branch Configuration

### 3.1 Configure Branch Protection

1. Go to **Settings** → **Branches**
2. Click **Add rule** for each branch (`main`, `branch-a`, `branch-b`)
3. Configure protection rules:

```
✅ Require a pull request before merging
✅ Require status checks to pass before merging
✅ Require branches to be up to date before merging
✅ Require conversation resolution before merging
✅ Include administrators
```

4. Add required status checks:
   - `detect-changes`
   - `generate-config`
   - `test-odoo-modules (instance1)`
   - `test-odoo-modules (instance2)`
   - `dependency-analysis`

### 3.2 Set Up Branch-Specific Content

#### Branch-A Setup
```bash
git checkout branch-a

# Add instance1-specific modules
cp -r /path/to/your/instance1/modules/* addons_instance1/

# Commit changes
git add addons_instance1/
git commit -m "Add instance1 specific modules"
git push origin branch-a
```

#### Branch-B Setup
```bash
git checkout branch-b

# Add instance2-specific modules
cp -r /path/to/your/instance2/modules/* addons_instance2/

# Commit changes
git add addons_instance2/
git commit -m "Add instance2 specific modules"
git push origin branch-b
```

## 🧪 Step 4: Local Testing Setup

### 4.1 Test Script Permissions

```bash
# Make scripts executable
chmod +x scripts/test_docker_modules.sh
chmod +x init-multiple-databases.sh
chmod +x entrypoint.sh
```

### 4.2 Verify Local Environment

```bash
# Test Docker setup
docker --version
docker-compose --version

# Test script help
./scripts/test_docker_modules.sh --help
```

### 4.3 Run Initial Local Test

```bash
# Run full test suite
./scripts/test_docker_modules.sh

# Expected output:
# [INFO] Starting Odoo module testing workflow...
# [INFO] Generating CI docker-compose configuration...
# [SUCCESS] CI docker-compose configuration generated
# [INFO] Generating graph_sync configuration...
# [SUCCESS] Configuration files generated
# [INFO] Starting services...
# ...
# [SUCCESS] All tests completed successfully!
```

## 🔄 Step 5: GitHub Actions Workflow Testing

### 5.1 Trigger First Workflow

```bash
# Make a small change to trigger workflow
echo "# Test commit" >> README.md
git add README.md
git commit -m "Test GitHub Actions workflow"
git push origin main
```

### 5.2 Monitor Workflow Execution

1. Go to **Actions** tab in GitHub
2. Click on the running workflow
3. Monitor each job's progress:
   - ✅ `detect-changes`
   - ✅ `generate-config`
   - ✅ `test-odoo-modules`
   - ✅ `dependency-analysis`
   - ✅ `notify`

### 5.3 Verify Workflow Artifacts

1. Click on completed workflow run
2. Scroll down to **Artifacts** section
3. Download and verify:
   - `ci-configurations`
   - `test-logs`
   - `dependency-analysis-results`

## 🔧 Step 6: GraphSync Service Setup

### 6.1 Create GraphSync Directory

```bash
mkdir -p graph_sync
cd graph_sync
```

### 6.2 Create GraphSync Dockerfile

```dockerfile
# graph_sync/Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/healthcheck || exit 1

# Run application
CMD ["python", "app.py"]
```

### 6.3 Create GraphSync Requirements

```txt
# graph_sync/requirements.txt
flask==2.3.3
requests==2.31.0
psycopg2-binary==2.9.7
neo4j==5.12.0
pyyaml==6.0.1
gunicorn==21.2.0
```

### 6.4 Create Basic GraphSync App

```python
# graph_sync/app.py
from flask import Flask, jsonify, request
import requests
import os
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
ODOO_INSTANCES = os.getenv('ODOO_INSTANCES', '').split(',')

@app.route('/healthcheck')
def healthcheck():
    return jsonify({"status": "healthy", "service": "graphsync"})

@app.route('/sync-all', methods=['POST'])
def sync_all():
    results = []
    for instance_url in ODOO_INSTANCES:
        if instance_url.strip():
            try:
                # Simulate sync operation
                logger.info(f"Syncing instance: {instance_url}")
                results.append({
                    "instance": instance_url,
                    "status": "synced",
                    "modules_count": 42  # Placeholder
                })
            except Exception as e:
                logger.error(f"Sync failed for {instance_url}: {e}")
                results.append({
                    "instance": instance_url,
                    "status": "failed",
                    "error": str(e)
                })
    
    return jsonify({"sync_results": results})

@app.route('/analyze-dependencies')
def analyze_dependencies():
    # Simulate dependency analysis
    return jsonify({
        "cycles_detected": False,
        "total_modules": 84,
        "dependency_count": 156,
        "analysis_timestamp": "2024-01-01T12:00:00Z",
        "instances_analyzed": len([url for url in ODOO_INSTANCES if url.strip()])
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
```

## 📊 Step 7: Monitoring and Validation

### 7.1 Workflow Monitoring Dashboard

Create a simple monitoring script:

```bash
#!/bin/bash
# monitor-workflow.sh

echo "🔍 GitHub Actions Workflow Monitor"
echo "================================="

# Check latest workflow runs
gh run list --limit 5 --json status,conclusion,createdAt,headBranch

# Check workflow status
gh run view --json status,conclusion,jobs
```

### 7.2 Health Check Script

```bash
#!/bin/bash
# health-check.sh

echo "🏥 Service Health Check"
echo "====================="

# Check local services
echo "Checking Odoo Instance 1..."
curl -f http://localhost:8070/web/health || echo "❌ Instance 1 down"

echo "Checking Odoo Instance 2..."
curl -f http://localhost:8069/web/health || echo "❌ Instance 2 down"

echo "Checking GraphSync..."
curl -f http://localhost:8000/healthcheck || echo "❌ GraphSync down"

echo "Checking PostgreSQL..."
docker-compose exec postgres pg_isready -U postgres || echo "❌ PostgreSQL down"
```

## 🚨 Step 8: Troubleshooting Common Issues

### 8.1 Workflow Fails on First Run

**Problem**: GitHub Actions workflow fails with permission errors

**Solution**:
1. Check repository permissions
2. Verify secrets are correctly set
3. Ensure workflow file syntax is correct

```bash
# Validate workflow syntax
gh workflow view odoo-ci-cd.yml
```

### 8.2 Docker Build Failures

**Problem**: Docker builds fail in GitHub Actions

**Solution**:
1. Test builds locally first
2. Check Dockerfile syntax
3. Verify base image availability

```bash
# Test local build
docker build -t test-odoo .
```

### 8.3 Service Health Check Failures

**Problem**: Services start but health checks fail

**Solution**:
1. Increase health check timeouts
2. Verify service endpoints
3. Check container logs

```bash
# Check service logs
docker-compose logs odoo1
docker-compose logs odoo2
docker-compose logs graphsync
```

### 8.4 Database Connection Issues

**Problem**: Odoo can't connect to PostgreSQL

**Solution**:
1. Verify database credentials
2. Check network connectivity
3. Ensure database initialization completed

```bash
# Test database connection
docker-compose exec postgres psql -U postgres -l
```

## ✅ Step 9: Validation Checklist

### 9.1 Pre-Deployment Checklist

- [ ] All required files are in repository
- [ ] GitHub secrets are configured
- [ ] Branch protection rules are set
- [ ] Local testing passes
- [ ] Docker images build successfully
- [ ] Services start and pass health checks

### 9.2 Post-Deployment Checklist

- [ ] GitHub Actions workflow runs successfully
- [ ] All jobs complete without errors
- [ ] Artifacts are generated correctly
- [ ] Notifications are received (if configured)
- [ ] Pull request comments work
- [ ] Dependency analysis completes

### 9.3 Ongoing Maintenance

- [ ] Monitor workflow execution times
- [ ] Review and update dependencies regularly
- [ ] Check for security updates
- [ ] Optimize Docker image sizes
- [ ] Review and update documentation

## 🎯 Step 10: Next Steps

### 10.1 Advanced Features

1. **Add more notification channels**
   - Microsoft Teams integration
   - Discord webhooks
   - Custom webhook endpoints

2. **Enhance dependency analysis**
   - Neo4j integration for graph storage
   - Visual dependency graphs
   - Historical dependency tracking

3. **Performance optimization**
   - Parallel test execution
   - Docker layer caching
   - Selective module testing

### 10.2 Production Considerations

1. **Security hardening**
   - Scan Docker images for vulnerabilities
   - Implement secret rotation
   - Add security policy enforcement

2. **Scalability improvements**
   - Multi-region deployment
   - Load balancing
   - Auto-scaling configurations

3. **Monitoring and observability**
   - Application performance monitoring
   - Log aggregation
   - Metrics collection and alerting

## 📞 Support

If you encounter issues during deployment:

1. **Check the logs**: Always start with container and workflow logs
2. **Review documentation**: Refer to README-GITHUB-ACTIONS.md
3. **Test locally**: Reproduce issues in local environment first
4. **Community support**: Check Odoo community forums and GitHub discussions

---

**🎉 Congratulations!** You've successfully set up a complete CI/CD pipeline for your Odoo multi-instance project with GitHub Actions!