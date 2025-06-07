# Odoo Multi-Instance CI/CD with GitHub Actions

This repository implements an automated CI/CD workflow for Odoo 17 Community Edition with multiple instances using GitHub Actions, Docker, and dependency analysis.

## 🏗️ Repository Structure

```
odoo17/
├── .github/
│   └── workflows/
│       └── odoo-ci-cd.yml          # Main GitHub Actions workflow
├── scripts/
│   └── test_docker_modules.sh      # Local testing script
├── addons_instance1/               # Custom modules for Instance 1
│   ├── module_custom_a/
│   ├── module_custom_b/
│   ├── module_custom_d/
│   ├── module_custom_k/
│   └── softifi_graph_module_dependency/
├── addons_instance2/               # Custom modules for Instance 2
│   ├── module_custom_a/
│   ├── module_custom_b/
│   ├── module_custom_d/
│   ├── module_custom_k/
│   └── softifi_graph_module_dependency/
├── addons/                         # Base Odoo addons
├── graph_sync/                     # Dependency analysis service
├── docker-compose.yml              # Local development setup
├── docker-compose.ci.yml           # CI environment (auto-generated)
├── Dockerfile                      # Odoo container definition
├── entrypoint.sh                   # Custom Odoo entrypoint
├── init-multiple-databases.sh      # PostgreSQL multi-DB setup
├── odoo1.conf                      # Instance 1 configuration
├── odoo2.conf                      # Instance 2 configuration
└── README-GITHUB-ACTIONS.md        # This file
```

## 🚀 Branch Strategy

### Main Branch
- Contains the base Odoo 17 Community Edition project
- Core infrastructure and shared configurations
- Base addons and common modules

### Branch-A (Instance 1)
- Contains `addons_instance1/` specific modules
- Triggers CI/CD for Instance 1 testing
- Merges back to main after validation

### Branch-B (Instance 2)
- Contains `addons_instance2/` specific modules
- Triggers CI/CD for Instance 2 testing
- Merges back to main after validation

## 🔄 GitHub Actions Workflow

### Triggers
The workflow triggers on:
- Push to `main`, `branch-a`, `branch-b`
- Pull requests to `main`, `branch-a`, `branch-b`

### Workflow Jobs

#### 1. **detect-changes**
- Detects which parts of the codebase changed
- Sets flags for instance-specific and base code changes
- Determines which tests need to run

#### 2. **generate-config**
- Dynamically generates `docker-compose.ci.yml`
- Creates `graph_sync` configuration based on branch
- Uploads configurations as artifacts

#### 3. **test-odoo-modules**
- Matrix strategy for testing both instances
- Builds and starts Docker services
- Runs Odoo module tests with health checks
- Validates module installation and functionality

#### 4. **dependency-analysis**
- Starts GraphSync service for dependency analysis
- Triggers synchronization of all Odoo instances
- Analyzes module dependencies and detects cycles
- Fails workflow if dependency cycles are found

#### 5. **notify**
- Sends notifications via Slack/Email
- Comments on pull requests with analysis results
- Reports test status and dependency analysis

### Dynamic Configuration Generation

The workflow dynamically generates configurations based on:
- **Branch detection**: Determines which instance addons to include
- **Change detection**: Only tests affected components
- **Environment variables**: Configures database connections and ports

## 🧪 Local Testing

### Prerequisites
- Docker and Docker Compose installed
- Bash shell (macOS/Linux)
- curl for health checks

### Running Tests Locally

```bash
# Make script executable (if not already)
chmod +x scripts/test_docker_modules.sh

# Run full test suite
./scripts/test_docker_modules.sh

# Run only module tests (skip dependency analysis)
./scripts/test_docker_modules.sh --test-only

# Run only dependency analysis
./scripts/test_docker_modules.sh --analyze-only

# Show service logs
./scripts/test_docker_modules.sh --logs

# Cleanup containers
./scripts/test_docker_modules.sh --cleanup-only

# Set custom timeout
./scripts/test_docker_modules.sh --timeout 600
```

### Test Script Features

- **Service Orchestration**: Starts PostgreSQL, Odoo instances, and GraphSync
- **Health Checks**: Validates all services are running correctly
- **Module Testing**: Runs Odoo tests for custom modules
- **Dependency Analysis**: Detects circular dependencies
- **Logging**: Comprehensive logging and error reporting
- **Cleanup**: Automatic cleanup on exit

## 🐳 Docker Configuration

### Services

#### PostgreSQL
- **Image**: `postgres:15`
- **Databases**: `odoo_db1`, `odoo_db2`
- **Users**: `odoo1`, `odoo2` with separate credentials
- **Initialization**: Automatic multi-database setup

#### Odoo Instance 1
- **Port**: `8070`
- **Database**: `odoo_db1`
- **Addons**: `addons_instance1/` + base `addons/`
- **Modules**: Auto-installs `base` + `softifi_graph_module_dependency`

#### Odoo Instance 2
- **Port**: `8069`
- **Database**: `odoo_db2`
- **Addons**: `addons_instance2/` + base `addons/`
- **Modules**: Auto-installs `base` + `softifi_graph_module_dependency`

#### GraphSync Service
- **Port**: `8000`
- **Purpose**: Module dependency analysis
- **Endpoints**: `/sync-all`, `/analyze-dependencies`, `/healthcheck`

### Volume Mounts
- **Instance Addons**: Read-only mounts for instance-specific modules
- **Base Addons**: Shared base Odoo addons
- **Data Persistence**: Separate volumes for each instance

## 🔍 Dependency Analysis

### GraphSync Service
The GraphSync service provides:
- **Module Discovery**: Scans all Odoo instances for installed modules
- **Dependency Mapping**: Creates dependency graphs
- **Cycle Detection**: Identifies circular dependencies
- **Health Monitoring**: Service health checks

### Analysis Endpoints
```bash
# Trigger synchronization
curl -X POST http://localhost:8000/sync-all

# Get dependency analysis
curl http://localhost:8000/analyze-dependencies

# Health check
curl http://localhost:8000/healthcheck
```

### Cycle Detection
If dependency cycles are detected:
1. **Local Testing**: Script exits with error code 1
2. **GitHub Actions**: Workflow fails and blocks merge
3. **Notifications**: Alerts sent via configured channels
4. **PR Comments**: Analysis results posted to pull request

## 📧 Notifications

### Slack Integration
```yaml
# Add to repository secrets
SLACK_WEBHOOK_URL: https://hooks.slack.com/services/...
```

### Email Notifications
```yaml
# Add to repository secrets
SMTP_SERVER: smtp.gmail.com
SMTP_PORT: 587
SMTP_USERNAME: your-email@gmail.com
SMTP_PASSWORD: your-app-password
NOTIFY_EMAIL: team@company.com
```

## 🛠️ Configuration Files

### GitHub Secrets Required
```
SLACK_WEBHOOK_URL          # Slack notifications
SMTP_SERVER               # Email server
SMTP_PORT                 # Email port
SMTP_USERNAME             # Email username
SMTP_PASSWORD             # Email password
NOTIFY_EMAIL              # Notification recipient
DOCKER_USERNAME           # Docker Hub (optional)
DOCKER_PASSWORD           # Docker Hub (optional)
```

### Environment Variables
```bash
# Database Configuration
DB_HOST=postgres
DB_PORT=5432
DB_USER=odoo1|odoo2
DB_PASSWORD=odoo1_pass|odoo2_pass
DB_NAME=odoo_db1|odoo_db2

# GraphSync Configuration
ODOO_INSTANCES=http://odoo1:8069,http://odoo2:8069
```

## 🚨 Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check service logs
./scripts/test_docker_modules.sh --logs

# Check container status
docker-compose -f docker-compose.ci.yml ps

# Restart services
./scripts/test_docker_modules.sh --cleanup-only
./scripts/test_docker_modules.sh
```

#### Database Connection Issues
```bash
# Check PostgreSQL logs
docker-compose -f docker-compose.ci.yml logs postgres

# Verify database creation
docker-compose -f docker-compose.ci.yml exec postgres psql -U postgres -l
```

#### Module Installation Failures
```bash
# Check Odoo logs
docker-compose -f docker-compose.ci.yml logs odoo1
docker-compose -f docker-compose.ci.yml logs odoo2

# Check module manifest files
find addons_instance1 -name '__manifest__.py' -exec head -20 {} \;
```

#### GraphSync Service Issues
```bash
# Check GraphSync health
curl -f http://localhost:8000/healthcheck

# Check GraphSync logs
docker-compose -f docker-compose.ci.yml logs graphsync

# Manual sync trigger
curl -X POST http://localhost:8000/sync-all
```

### Debug Mode
```bash
# Run with verbose logging
DEBUG=1 ./scripts/test_docker_modules.sh

# Keep containers running after tests
NO_CLEANUP=1 ./scripts/test_docker_modules.sh
```

## 📈 Performance Optimization

### Docker Build Optimization
- **Multi-stage builds**: Reduce image size
- **Layer caching**: Optimize build times
- **Parallel builds**: Use BuildKit for faster builds

### Test Optimization
- **Parallel testing**: Matrix strategy for concurrent tests
- **Selective testing**: Only test changed modules
- **Health check optimization**: Faster service readiness detection

### Resource Management
- **Memory limits**: Configure container memory limits
- **CPU limits**: Set appropriate CPU constraints
- **Volume optimization**: Use tmpfs for temporary data

## 🔒 Security Considerations

### Secrets Management
- Use GitHub Secrets for sensitive data
- Rotate database passwords regularly
- Limit container privileges

### Network Security
- Internal Docker networks
- No exposed database ports in production
- HTTPS for external communications

### Access Control
- Branch protection rules
- Required status checks
- Review requirements for sensitive changes

## 📚 Additional Resources

- [Odoo Documentation](https://www.odoo.com/documentation/17.0/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [PostgreSQL Multi-Database Setup](https://hub.docker.com/_/postgres)

## 🤝 Contributing

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/new-module`
3. **Make changes**: Add your custom modules to appropriate instance directory
4. **Test locally**: Run `./scripts/test_docker_modules.sh`
5. **Create pull request**: Target appropriate branch (branch-a or branch-b)
6. **Wait for CI**: GitHub Actions will validate your changes
7. **Review and merge**: After successful validation

## 📄 License

This project follows the same license as Odoo Community Edition (LGPL-3).