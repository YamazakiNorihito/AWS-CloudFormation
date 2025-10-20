#!/bin/bash

# Usage: ./npm-install.sh <package-name> [<package-name2> ...]
# Example: ./npm-install.sh axios date-fns

if [ -z "$1" ]; then
  echo "Error: Package name is required"
  echo "Usage: ./npm-install.sh <package-name> [<package-name2> ...]"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PACKAGE_LIST="$@"

echo ""
echo "📦 Installing in function/ as devDependency..."
cd "$SCRIPT_DIR/function" || exit 1
npm install --save-dev $PACKAGE_LIST

echo ""
echo "📦 Installing in layer/nodejs/ as dependency..."
cd "$SCRIPT_DIR/layer/nodejs" || exit 1
npm install --save $PACKAGE_LIST

echo ""
echo "✅ Successfully installed $PACKAGE_LIST in both directories"
echo 