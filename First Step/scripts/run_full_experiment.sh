#!/usr/bin/env bash
# Full run: 150 agents = 5 conditions x 30 agents (see conditions.tsv).
#
# Requires: Node, npm, R + packages, CURSOR_API_KEY (see RUN_INSTRUCTIONS.md)
#
# Usage:
#   export CURSOR_API_KEY='crsr_...'
#   ./scripts/run_full_experiment.sh
#
# Optional overrides before running:
#   CONCURRENCY=15 LAUNCH_DELAY_MS=3000 ./scripts/run_full_experiment.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
cd "$ROOT"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

need() {
	local cmd="$1"
	if command -v "$cmd" >/dev/null 2>&1; then
		return 0
	fi
	echo "ERROR: Missing required command: $cmd"
	echo "See RUN_INSTRUCTIONS.md"
	exit 1
}

need node
need npm
need Rscript

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
	echo "ERROR: CURSOR_API_KEY is not set."
	echo "export CURSOR_API_KEY='crsr_...'"
	exit 1
fi

if [[ ! -d "$ROOT/node_modules/@cursor/sdk" ]]; then
	echo "Installing npm dependencies..."
	npm install
fi

# Force full design (avoid a leftover N_PER_CONDITION=1 from a pilot shell).
export N_TOTAL=150
export N_PER_CONDITION=30
export CONCURRENCY="${CONCURRENCY:-10}"
export LAUNCH_DELAY_MS="${LAUNCH_DELAY_MS:-5000}"

echo "============================================"
echo "Full experiment: 150 agents (5 x 30)"
echo "N_TOTAL=$N_TOTAL  N_PER_CONDITION=$N_PER_CONDITION"
echo "CONCURRENCY=$CONCURRENCY  LAUNCH_DELAY_MS=$LAUNCH_DELAY_MS"
echo "============================================"
echo ""

npm run launch:cursor

echo ""
echo "Launch finished. Next:"
echo "  ./scripts/collect_results.sh"
echo "  Rscript scripts/analyze_results.R"
