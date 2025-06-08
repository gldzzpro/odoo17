# Simplified Odoo CI/CD Setup

This repository contains a simplified CI/CD workflow for Odoo that focuses on dependency analysis and email notifications.

## 🚀 Quick Start

The CI/CD workflow will automatically run when you push to `branch-A` or `branch-B`, or when you create a pull request.

## 📁 Files Overview

### Workflow File
- `.github/workflows/simple-odoo-ci.yml` - Main CI/CD workflow

### Scripts
- `scripts/generate_compose.sh` - Generates Docker Compose configuration
- `scripts/wait_for_health.sh` - Waits for services to be healthy
- `scripts/trigger_sync.sh` - Triggers dependency analysis
- `scripts/analyze_cycles.sh` - Analyzes dependency cycles
- `scripts/notify_email.sh` - Sends email notifications
- `scripts/send_email.py` - Python email utility

## 📧 Email Setup

The workflow is configured to send emails to `golden.farhat@gmail.com`. To enable actual email sending, you have several options:

### Option 1: Formspree (Recommended - Free & Easy)

1. Go to [https://formspree.io/](https://formspree.io/)
2. Create a free account
3. Create a new form
4. Copy your form ID (e.g., `xpzgkqyw`)
5. Add it as a repository secret:
   - Go to your GitHub repository
   - Settings → Secrets and variables → Actions
   - Add new secret: `FORMSPREE_FORM_ID` with your form ID

### Option 2: SendGrid API

1. Create a SendGrid account
2. Generate an API key
3. Add it as a repository secret: `SENDGRID_API_KEY`
4. Uncomment the SendGrid section in the workflow

### Option 3: GitHub Issues (Fallback)

The Python script can also create GitHub issues as notifications if email services are not configured.

## 🔧 Workflow Features

### What it does:
- ✅ Checks out your code
- ✅ Sets up Docker and Docker Compose
- ✅ Generates a simple Docker configuration
- ✅ Starts Postgres and Odoo services
- ✅ Waits for services to be healthy
- ✅ Analyzes module dependencies
- ✅ Checks for circular dependencies
- ✅ Sends email notifications
- ✅ Cleans up resources

### What it doesn't do (simplified):
- ❌ Complex security configurations
- ❌ Multiple environment setups
- ❌ Slack notifications
- ❌ Complex artifact management
- ❌ Multi-stage deployments

## 🏃‍♂️ Running Locally

You can test the scripts locally:

```bash
# Make scripts executable (already done)
chmod +x scripts/*.sh

# Generate Docker Compose
./scripts/generate_compose.sh

# Start services
docker-compose -f docker-compose.simple.yml up -d

# Wait for health
./scripts/wait_for_health.sh

# Run analysis
./scripts/trigger_sync.sh
./scripts/analyze_cycles.sh

# Send test email
python3 scripts/send_email.py "Test Subject" "Test Body" "your-email@example.com"

# Cleanup
docker-compose -f docker-compose.simple.yml down
```

## 🔍 Troubleshooting

### Common Issues:

1. **Email not sending**: Check if `FORMSPREE_FORM_ID` secret is set correctly
2. **Docker issues**: Ensure Docker is available in the GitHub runner
3. **Permission denied**: Scripts should be executable (chmod +x)
4. **Service health checks failing**: Check Docker logs in the workflow

### Debugging:

- Check the GitHub Actions logs for detailed error messages
- Look at the "Cleanup" step to see Docker logs
- Verify that your repository has the correct branch names (`branch-A`, `branch-B`)

## 📝 Customization

### Change email recipient:
Edit the email address in:
- `.github/workflows/simple-odoo-ci.yml` (line with `golden.farhat@gmail.com`)
- `scripts/notify_email.sh`

### Change trigger branches:
Edit the `on.push.branches` section in the workflow file.

### Add more checks:
Modify `scripts/trigger_sync.sh` and `scripts/analyze_cycles.sh` to add custom analysis logic.

## 🆘 Support

If you encounter issues:
1. Check the GitHub Actions logs
2. Verify all secrets are properly set
3. Ensure your repository structure matches the expected layout
4. Test scripts locally first

---

**Note**: This is a simplified CI/CD setup designed for ease of use and minimal configuration overhead. For production environments, consider adding more robust security measures and error handling.