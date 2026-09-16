#!/usr/bin/env bash
# Pilot: one agent per condition (5 agents total).
#
# Requires: Node, npm, R + packages (see RUN_INSTRUCTIONS.md), CURSOR_API_KEY
#
# Usage (from anywhere):
#   export CURSOR_API_KEY="cursor_..."
#   ./scripts/run_pilot_one_per_condition.sh
#
# Optional overrides:
#   CONCURRENCY=2 LAUNCH_DELAY_MS=1000 ./scripts/run_pilot_one_per_condition.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
cd "$ROOT"

# Terminal often has a minimal PATH; Homebrew lives here on most Macs.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

need() {
	local cmd="$1"
	if command -v "$cmd" >/dev/null 2>&1; then
		return 0
	fi
	echo "ERROR: Missing required command: $cmd"
	if [[ "$cmd" == "node" || "$cmd" == "npm" ]]; then
		echo "Install Node.js (includes npm), for example:"
		echo "  brew install node"
		echo "Then open a new terminal, or run:"
		echo "  export PATH=\"/opt/homebrew/bin:/usr/local/bin:\$PATH\""
		echo "Verify:  which node && node --version && npm --version"
	elif [[ "$cmd" == "Rscript" ]]; then
		echo "Install R, for example:"
		echo "  brew install r"
	fi
	echo "Full setup: RUN_INSTRUCTIONS.md"
	exit 1
}

need node
need npm
need Rscript

if [[ -z "${CURSOR_API_KEY:-}" ]]; then
	echo "ERROR: CURSOR_API_KEY is not set."
	echo "Export it first: export CURSOR_API_KEY=\"cursor_...\""
	exit 1
fi

if [[ ! -d "$ROOT/node_modules/@cursor/sdk" ]]; then
	echo "Installing npm dependencies..."
	npm install
fi

export N_PER_CONDITION="${N_PER_CONDITION:-1}"
export EXPERIMENT_OUTPUT="${EXPERIMENT_OUTPUT:-"Second Step/pilot_results"}"
export CONCURRENCY="${CONCURRENCY:-2}"
export LAUNCH_DELAY_MS="${LAUNCH_DELAY_MS:-1000}"

echo "Pilot: N_PER_CONDITION=$N_PER_CONDITION  (5 conditions -> $((N_PER_CONDITION * 5)) agents)"
echo "EXPERIMENT_OUTPUT=$EXPERIMENT_OUTPUT (for collect + analyze after pilot)"
echo "CONCURRENCY=$CONCURRENCY  LAUNCH_DELAY_MS=$LAUNCH_DELAY_MS"
npm run launch:cursor
echo ""
echo "Pilot launcher finished. Next (same shell keeps EXPERIMENT_OUTPUT):"
echo "  ./scripts/collect_results.sh"
echo "  Rscript scripts/analyze_results.R"
echo "New terminal: export EXPERIMENT_OUTPUT=\"${EXPERIMENT_OUTPUT}\" before collect/analyze."
