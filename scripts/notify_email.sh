#!/bin/bash

# Send email notification when dependency cycles are found
# This script sends an email notification about dependency issues

set -e

echo "Sending email notification about dependency cycles..."

# Read analysis results
if [ -f "output/dependency_analysis.json" ]; then
    ANALYSIS_CONTENT=$(cat output/dependency_analysis.json)
else
    ANALYSIS_CONTENT="No analysis file found"
fi

# Create email subject and body
SUBJECT="🚨 Odoo CI/CD: Dependency Cycles Detected - Branch ${GITHUB_REF_NAME:-$(git branch --show-current)}"

BODY="Dependency Cycle Alert

❌ Dependency cycles or issues have been detected in your Odoo project.

Branch: ${GITHUB_REF_NAME:-$(git branch --show-current)}
Commit: ${GITHUB_SHA:-$(git rev-parse HEAD)}
Author: ${GITHUB_ACTOR:-$(git log -1 --pretty=format:'%an')}
Workflow: ${GITHUB_WORKFLOW:-Manual}
Run: ${GITHUB_RUN_NUMBER:-N/A}

Analysis Results:
$ANALYSIS_CONTENT

Action Required:
Please review your module dependencies and resolve any circular dependencies before merging.

View full logs: ${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-your-repo}/actions/runs/${GITHUB_RUN_ID:-0}

---
This is an automated message from your CI/CD pipeline."

# Send email using the Python script
if [ -f "scripts/send_email.py" ]; then
    echo "Sending email via Python script..."
    python3 scripts/send_email.py "$SUBJECT" "$BODY" "golden.farhat@gmail.com"
else
    echo "Python email script not found. Using fallback notification."
    echo "Subject: $SUBJECT"
    echo "Body: $BODY"
fi

echo "✅ Email notification process completed"