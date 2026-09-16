#!/usr/bin/env bash
# collect_results.sh — Gather results from all agent runs
#
# Copies each agent's results.csv, llms.txt, and log into output/arm_*/agent_NNN/
#
# Also produces a combined results_all.csv with all agents' one-row results.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPERIMENT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$EXPERIMENT_DIR/output"
CONDITIONS_FILE="$EXPERIMENT_DIR/conditions.tsv"

if [[ ! -f "$CONDITIONS_FILE" ]]; then
    echo "ERROR: Required file not found: $CONDITIONS_FILE"
    exit 1
fi

# macOS ships Bash 3.2 — no mapfile. Build ARMS from conditions.tsv with awk + read.
ARMS=()
while IFS= read -r arm; do
    [[ -n "$arm" ]] && ARMS+=("$arm")
done < <(awk -F '\t' 'NR > 1 && $1 !~ /^#/ && $1 != "" { print $1 }' "$CONDITIONS_FILE")
mkdir -p "$OUTPUT_DIR"

# Match Node's os.tmpdir(): macOS usually uses $TMPDIR; Linux often /tmp.
# With `set -u`, `for x in "${ARRAY[@]}"` can error when ARRAY is empty; use indexed loops.
BASES=()
add_base() {
    local d="${1:-}"
    [[ -z "$d" ]] && return
    d="${d%/}"
    local i
    for ((i = 0; i < ${#BASES[@]}; i++)); do
        [[ "${BASES[i]}" == "$d" ]] && return
    done
    BASES+=("$d")
}
add_base "${TMPDIR:-}"
add_base "/tmp"
add_base "/private/tmp"

paths_joined=""
for ((j = 0; j < ${#BASES[@]}; j++)); do
    paths_joined="${paths_joined:+$paths_joined }${BASES[j]}"
done
echo "Collecting results (search paths: $paths_joined)..."
echo ""

COMBINED_CSV="$OUTPUT_DIR/results_all.csv"
HEADER_WRITTEN=false

TOTAL=0
SUCCESSFUL=0

for ((a = 0; a < ${#ARMS[@]}; a++)); do
    arm="${ARMS[a]}"
    ARM_DIR="$OUTPUT_DIR/arm_${arm}"
    mkdir -p "$ARM_DIR"

    # Find all agent directories for this arm under any tmp base
    for ((bi = 0; bi < ${#BASES[@]}; bi++)); do
        base="${BASES[bi]}"
        [[ -d "$base" ]] || continue
        for agent_dir in "$base"/mw_agent_"${arm}"_*; do
            [[ -d "$agent_dir" ]] || continue

            AGENT_ID=$(basename "$agent_dir" | sed 's/mw_agent_//')
            DEST="$ARM_DIR/$AGENT_ID"
            mkdir -p "$DEST"

            TOTAL=$((TOTAL + 1))

            # Copy outputs
            for f in results.csv llms.txt agent_log.txt; do
                if [[ -f "$agent_dir/$f" ]]; then
                    cp "$agent_dir/$f" "$DEST/"
                fi
            done

            # Copy any scripts the agent created
            for f in "$agent_dir"/*.R "$agent_dir"/*.r; do
                [[ -f "$f" ]] && cp "$f" "$DEST/"
            done

            # Append to combined CSV
            if [[ -f "$agent_dir/results.csv" ]]; then
                SUCCESSFUL=$((SUCCESSFUL + 1))
                if [[ "$HEADER_WRITTEN" == false ]]; then
                    # First file: include header
                    head -1 "$agent_dir/results.csv" > "$COMBINED_CSV"
                    HEADER_WRITTEN=true
                fi
                # Append data row (skip header)
                tail -n +2 "$agent_dir/results.csv" >> "$COMBINED_CSV"
                echo "  ✓ $AGENT_ID"
            else
                echo "  ✗ $AGENT_ID (no results.csv)"
            fi
        done
    done
done

echo ""
echo "============================================"
echo "Collection complete"
echo "  Total agents:      $TOTAL"
echo "  Successful:        $SUCCESSFUL"
echo "  Failed/incomplete: $((TOTAL - SUCCESSFUL))"
echo ""
echo "Combined results: $COMBINED_CSV"
echo "Individual results: $OUTPUT_DIR/arm_*/agent_*/results.csv"
echo "============================================"
