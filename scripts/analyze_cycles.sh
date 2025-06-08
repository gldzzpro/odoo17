#!/bin/bash

# Analyze dependency cycles and issues
# This script analyzes the dependency analysis results and sets output variables

set -e

echo "Analyzing dependency cycles..."

# Check if dependency analysis file exists
if [ ! -f "output/dependency_analysis.json" ]; then
    echo "❌ Dependency analysis file not found"
    echo "cycles_found=true" >> $GITHUB_OUTPUT
    exit 1
fi

# Parse the JSON results
if command -v jq > /dev/null; then
    # Use jq if available
    HAS_CYCLES=$(jq -r '.summary.has_cycles' output/dependency_analysis.json)
    ERRORS_COUNT=$(jq -r '.errors | length' output/dependency_analysis.json)
    WARNINGS_COUNT=$(jq -r '.warnings | length' output/dependency_analysis.json)
    CIRCULAR_DEPS=$(jq -r '.circular_dependencies | length' output/dependency_analysis.json)
else
    # Fallback to grep/sed parsing
    HAS_CYCLES=$(grep '"has_cycles"' output/dependency_analysis.json | sed 's/.*: *\([^,}]*\).*/\1/' | tr -d '"')
    ERRORS_COUNT=$(grep -o '"errors".*\[.*\]' output/dependency_analysis.json | grep -o '\[.*\]' | grep -o ',' | wc -l || echo "0")
    WARNINGS_COUNT=$(grep -o '"warnings".*\[.*\]' output/dependency_analysis.json | grep -o '\[.*\]' | grep -o ',' | wc -l || echo "0")
    CIRCULAR_DEPS=$(grep -o '"circular_dependencies".*\[.*\]' output/dependency_analysis.json | grep -o '\[.*\]' | grep -o ',' | wc -l || echo "0")
fi

echo "Analysis Results:"
echo "  Has cycles: $HAS_CYCLES"
echo "  Errors: $ERRORS_COUNT"
echo "  Warnings: $WARNINGS_COUNT"
echo "  Circular dependencies: $CIRCULAR_DEPS"

# Determine if there are issues
ISSUES_FOUND=false

if [ "$HAS_CYCLES" = "true" ] || [ "$ERRORS_COUNT" -gt 0 ] || [ "$CIRCULAR_DEPS" -gt 0 ]; then
    ISSUES_FOUND=true
    echo "❌ Issues detected in dependency analysis"
else
    echo "✅ No dependency issues found"
fi

# Set GitHub Actions output
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "cycles_found=$ISSUES_FOUND" >> $GITHUB_OUTPUT
    echo "errors_count=$ERRORS_COUNT" >> $GITHUB_OUTPUT
    echo "warnings_count=$WARNINGS_COUNT" >> $GITHUB_OUTPUT
    echo "circular_deps=$CIRCULAR_DEPS" >> $GITHUB_OUTPUT
else
    # For local testing
    echo "cycles_found=$ISSUES_FOUND"
    echo "errors_count=$ERRORS_COUNT"
    echo "warnings_count=$WARNINGS_COUNT"
    echo "circular_deps=$CIRCULAR_DEPS"
fi

# Exit with appropriate code
if [ "$ISSUES_FOUND" = "true" ]; then
    exit 1
else
    exit 0
fi