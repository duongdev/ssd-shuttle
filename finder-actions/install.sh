#!/bin/bash
# Install Shuttle Finder Quick Actions

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICES_DIR="$HOME/Library/Services"

echo "Installing Shuttle Finder Quick Actions..."

# Create Services directory if it doesn't exist
mkdir -p "$SERVICES_DIR"

# Copy workflows
for workflow in "$SCRIPT_DIR"/*.workflow; do
    if [[ -d "$workflow" ]]; then
        name=$(basename "$workflow")
        echo "  Installing: $name"
        rm -rf "$SERVICES_DIR/$name"
        cp -R "$workflow" "$SERVICES_DIR/"
    fi
done

echo ""
echo "Installation complete!"
echo ""
echo "Quick Actions are now available in Finder:"
echo "  1. Right-click any folder"
echo "  2. Select 'Quick Actions' from the menu"
echo "  3. Choose 'Shuttle - Offload to SSD' or 'Shuttle - Restore from SSD'"
echo ""
echo "Note: You may need to enable them in:"
echo "  System Settings → Privacy & Security → Extensions → Finder Extensions"
