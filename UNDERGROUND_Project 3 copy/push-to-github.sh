#!/bin/bash
# Run this script from your vault folder to create GitHub repo and push

set -e

REPO_NAME="UNDERGROUND-Project-3"
VISIBILITY="public"  # or "private"

echo "🔍 Checking for gh CLI..."
if ! command -v gh &> /dev/null; then
    echo "📦 Installing gh via Homebrew..."
    brew install gh
fi

echo "🔐 Checking GitHub auth..."
if ! gh auth status &> /dev/null; then
    echo "🌐 Opening browser for GitHub login..."
    gh auth login
fi

echo "🚀 Creating repo and pushing..."
cd ~/Downloads/UNDERGROUND_Project\ 3\ copy
gh repo create "$REPO_NAME" --$VISIBILITY --source=. --remote=origin --push

echo ""
echo "✅ Done! Your repo is at: https://github.com/$(gh api user --jq .login)/$REPO_NAME"