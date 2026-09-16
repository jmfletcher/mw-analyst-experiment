#!/usr/bin/env bash
# Opus 4.6 pilot: 5 agents per condition (25 agents total).
# Writes to Third Step/pilot_opus46 — does NOT touch Second Step/results.
#
# Usage:
#   export CURSOR_API_KEY='crsr_...'
#   ./scripts/run_pilot_opus46.sh

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

export N_TOTAL=25
export N_PER_CONDITION=5
export CURSOR_MODEL="${CURSOR_MODEL:-claude-opus-4-6}"
export EXPERIMENT_OUTPUT="${EXPERIMENT_OUTPUT:-"Third Step/pilot_opus46"}"
export CONCURRENCY="${CONCURRENCY:-4}"
export LAUNCH_DELAY_MS="${LAUNCH_DELAY_MS:-3000}"

echo "============================================"
echo "Opus 4.6 pilot: 25 agents (5 conditions x 5)"
echo "CURSOR_MODEL=$CURSOR_MODEL"
echo "EXPERIMENT_OUTPUT=$EXPERIMENT_OUTPUT"
echo "N_TOTAL=$N_TOTAL  N_PER_CONDITION=$N_PER_CONDITION"
echo "CONCURRENCY=$CONCURRENCY  LAUNCH_DELAY_MS=$LAUNCH_DELAY_MS"
echo "============================================"
echo ""

npm run launch:cursor

echo ""
echo "Pilot finished. Next (same shell keeps EXPERIMENT_OUTPUT):"
echo "  ./scripts/collect_results.sh"
echo "  Rscript scripts/analyze_results.R"
echo "New terminal: export EXPERIMENT_OUTPUT=\"${EXPERIMENT_OUTPUT}\" before collect/analyze."
