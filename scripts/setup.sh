#!/bin/bash
# Installs and configures Git hooks for the lopes.id repository.
#
# ACTIONS
# - Installs the Git pre-commit hook at .git/hooks/pre-commit
# - Ensures executable permissions
#
# DESIGN
# This script is idempotent and safe to run multiple times.
# The real enforcement logic lives in: scripts/pre-commit.sh
#
# USAGE
# Run once after cloning the repository:
#   chmod +x scripts/setup.sh
#   ./scripts/setup.sh
#
# AUTHOR: Joe Lopes <https://lopes.id>
# CREATED: 2025-12-29
# LICENSE: MIT
##

set -e

ROOT="$(git rev-parse --show-toplevel)"

echo "🔧 Setting up Git hooks..."

mkdir -p "$ROOT/.git/hooks"

GIT_HOOK="$ROOT/.git/hooks/pre-commit"

cat > "$GIT_HOOK" << EOF
#!/bin/bash
# Git pre-commit hook
"$ROOT/scripts/pre-commit.sh"
EOF

chmod +x "$GIT_HOOK"
chmod +x "$ROOT/scripts/pre-commit.sh"

echo "✅ Git hooks are correctly installed."
