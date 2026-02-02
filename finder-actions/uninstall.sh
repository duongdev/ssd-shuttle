#!/bin/bash
# Uninstall Shuttle Finder Quick Actions

SERVICES_DIR="$HOME/Library/Services"

echo "Uninstalling Shuttle Finder Quick Actions..."

removed=0

for workflow in "Shuttle - Offload to SSD.workflow" "Shuttle - Restore from SSD.workflow"; do
    if [[ -d "$SERVICES_DIR/$workflow" ]]; then
        echo "  Removing: $workflow"
        rm -rf "$SERVICES_DIR/$workflow"
        ((removed++))
    fi
done

if [[ $removed -eq 0 ]]; then
    echo "  No workflows found to remove."
else
    echo ""
    echo "Uninstallation complete! Removed $removed workflow(s)."
fi
