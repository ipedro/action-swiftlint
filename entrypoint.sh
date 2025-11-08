#!/bin/bash

# Fix git safe.directory issue in GitHub Actions Docker containers
git config --global --add safe.directory /github/workspace

# convert swiftlint's output into GitHub Actions Logging commands
# https://help.github.com/en/github/automating-your-workflow-with-github-actions/development-tools-for-github-actions#logging-commands

function stripPWD() {
    if [ -n "${WORKING_DIRECTORY}" ]; then
        cd - > /dev/null
    fi
    sed -E "s/$(pwd|sed 's/\//\\\//g')\///"
}

function convertToGitHubActionsLoggingCommands() {
    sed -E 's/^(.*):([0-9]+):([0-9]+): (warning|error|[^:]+): (.*)/::\4 file=\1,line=\2,col=\3::\5/'
}

if [ -n "${WORKING_DIRECTORY}" ]; then
	cd ${WORKING_DIRECTORY}
fi

# If DIFF_BASE is set and not empty, lint only changed files
if [ -n "${DIFF_BASE}" ]; then
	# Fetch the base branch to ensure we have the reference
	git fetch origin "${DIFF_BASE}:refs/remotes/origin/${DIFF_BASE}" 2>/dev/null || true
	
	# Try different comparison methods
	if git rev-parse "origin/${DIFF_BASE}" >/dev/null 2>&1; then
		# Compare against origin/base
		changedFiles=$(git diff --name-only --diff-filter=d origin/${DIFF_BASE}...HEAD -- '*.swift' 2>/dev/null || echo "")
	elif git rev-parse "${DIFF_BASE}" >/dev/null 2>&1; then
		# Fallback: try base branch name directly
		changedFiles=$(git diff --name-only --diff-filter=d ${DIFF_BASE}...HEAD -- '*.swift' 2>/dev/null || echo "")
	else
		echo "Warning: Could not resolve base ref '${DIFF_BASE}', linting all files"
		changedFiles=""
	fi

	if [ -n "$changedFiles" ]; then
		echo "Linting changed files in PR:"
		echo "$changedFiles"
		set -o pipefail && swiftlint "$@" -- $changedFiles | stripPWD | convertToGitHubActionsLoggingCommands
	else
		echo "No Swift files changed in this PR"
		exit 0
	fi
else
	# No DIFF_BASE - lint all Swift files
	echo "Linting all Swift files"
	set -o pipefail && swiftlint "$@" | stripPWD | convertToGitHubActionsLoggingCommands
fi
