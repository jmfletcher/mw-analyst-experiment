#!/usr/bin/env bash
# launch_experiment.sh - Run the minimum wage many-analyst experiment with Cursor
#
# Usage:
#   cd /path/to/mw-analyst-experiment/scripts
#   ./launch_experiment.sh
#
# Monitor progress:
#   ls /tmp/mw_agent_*/results.csv 2>/dev/null | wc -l

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPERIMENT_DIR="$(dirname "$SCRIPT_DIR")"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

if [[ ! -d "$EXPERIMENT_DIR/node_modules/@cursor/sdk" ]]; then
    echo "Installing npm dependencies..."
    (cd "$EXPERIMENT_DIR" && npm install)
fi

cd "$EXPERIMENT_DIR"
npm run launch:cursor
echo ""
echo "Launch finished. Next: ./scripts/collect_results.sh"
