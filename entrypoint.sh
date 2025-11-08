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
	changedFiles=$(git --no-pager diff --name-only --relative FETCH_HEAD $(git merge-base FETCH_HEAD $DIFF_BASE) -- '*.swift')

	if [ -z "$changedFiles" ]; then
		echo "No Swift file changed in this PR"
		exit 0
	fi
	
	echo "Linting changed files:"
	echo "$changedFiles"
	set -o pipefail && swiftlint "$@" -- $changedFiles | stripPWD | convertToGitHubActionsLoggingCommands
else
	# No DIFF_BASE - lint all Swift files
	echo "Linting all Swift files"
	set -o pipefail && swiftlint "$@" | stripPWD | convertToGitHubActionsLoggingCommands
fi
