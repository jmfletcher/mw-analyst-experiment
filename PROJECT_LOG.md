# Project log — Minimum wage many-analyst experiment (this workspace)

This document records what was implemented and operated in **this** repository through the **first complete 150-agent run**, so a **second wave** (e.g. revised instructions) can be developed against a clear baseline.

## Origin and purpose

- **Substantive goal:** Many autonomous agents analyze the same state–year minimum wage and employment panel using difference-in-differences, randomized only by **literature prime** (prior), to study whether prompted priors shift empirical choices and reported effects.
- **Code lineage:** Forked from Scott Cunningham’s `mw-analyst-experiment` design; this workspace connected it to **Cursor** programmatic agents instead of the original **Claude Code CLI** (`claude -p`) flow.

## Design: five conditions (first wave)

Condition IDs and labels are defined in `conditions.tsv`:

| ID (`agent_id` prefix) | Label           | Literature file        |
|--------------------------|-----------------|-------------------------|
| `none`                   | None            | *(none)*               |
| `null_short`             | Null Short      | `PRIME_NULL_SHORT.md`  |
| `null_cites`             | Null Cites      | `PRIME_NULL_CITES.md`   |
| `negative_short`         | Negative Short  | `PRIME_NEGATIVE_SHORT.md` |
| `negative_cites`         | Negative Cites  | `PRIME_NEGATIVE_CITES.md` |

**Scale:** **150 agents** = **30 per condition** × 5 conditions.

**Deliverables per agent:** `results.csv` (one row) and `llms.txt`, written in each agent’s temp workspace.

## Technical stack (first wave)

| Piece | Role |
|--------|------|
| **Node + `@cursor/sdk`** | Launches **local** Cursor agents (`Agent.create`, `send`, `wait`). |
| **`CURSOR_API_KEY`** | Required; distinct from Ultra subscription login. Verified with `npm run verify:cursor`. |
| **`scripts/launch_experiment_cursor.mjs`** | Builds workspaces, copies data and MD instructions, runs agents with concurrency and launch delay. |
| **R + `did` / `contdid` / etc.** | Used **inside** each agent workspace (not by the launcher itself). |
| **`scripts/collect_results.sh`** | Copies agent outputs into **`$EXPERIMENT_OUTPUT`** (default **`output`** if unset; launcher shells default to **`Second Step/pilot_results`** / **`Second Step/results`**). |
| **`scripts/analyze_results.R`** | Reads **`$EXPERIMENT_OUTPUT/results_all.csv`** (or first CLI argument, default **`output`**); writes plots into the same directory. |

Convenience scripts:

- **`scripts/run_pilot_one_per_condition.sh`** — 5 agents (`N_PER_CONDITION=1`); sets **`EXPERIMENT_OUTPUT=Second Step/pilot_results`** by default (quote paths with spaces).
- **`scripts/run_full_experiment.sh`** — pins **`N_TOTAL=250`** and **`N_PER_CONDITION=50`** (so a leftover pilot env var cannot shrink the full run); sets **`EXPERIMENT_OUTPUT=Second Step/results`** by default.

## Second wave scale (current root protocol)

**250 agents** = **50 per condition** × 5 conditions, with updated methodology language (e.g. TWFE allowed in `DID_METHODOLOGY.md`). First-wave **150 × 30** remains documented above and frozen under `First Step/`. **Collected results** for this wave default to **`Second Step/results`** (pilot: **`Second Step/pilot_results`**) via **`EXPERIMENT_OUTPUT`**. Extended summaries and extra plots: **`scripts/analyze_second_step_detail.R`** → **`Second Step/analysis/`**.

## Issues encountered and fixes

1. **Auth `401` on `GET /v1/models`:** Needed a real **Cursor User API key** from the dashboard (`Cloud Agents` / `Integrations`), not placeholders or third-party keys.
2. **`ByteString` / character 8216:** Curly Unicode quotes in the key broke HTTP headers. **`scripts/cursor_auth_util.mjs`** normalizes keys and model ids; launch passes **`apiKey`** explicitly into `Agent.create`.
3. **`agent[Symbol.asyncDispose] is not a function`:** **`Agent.create` returns a Promise** — fixed by **`await Agent.create(...)`**.
4. **`collect_results.sh`:** **`mapfile` missing on macOS Bash 3.2** — replaced with **`awk` + `while read`**. **`set -u` + empty arrays** — switched to **indexed `for ((i=0; ...))`** loops.
5. **Results not under `/tmp`:** Node **`os.tmpdir()`** on macOS is usually **`$TMPDIR`** — collector searches **`$TMPDIR`**, `/tmp`, and `/private/tmp`.
6. **Terminal prompt after pilot:** Removed **`exec`** from pilot/full launchers so the shell session survives **`npm run launch:cursor`**.

## Archive: `First Step/`

**`First Step/`** holds a **filesystem snapshot** of the first-wave project (same layout as root), **excluding** `node_modules/`, `output/`, and `.git/`. Use it to **diff** or restore wording before second-wave edits at the repo root.

See **`First Step/ARCHIVE_NOTE.md`** for what the snapshot contains.

## Second wave (your next step)

You plan to **edit markdown instructions** at the repo root (e.g. `INSTRUCTIONS_SHARED.md`, `DID_METHODOLOGY.md`, or new instruction files) while keeping **`First Step/`** as the frozen reference for wave one.

Operational sequence for a new wave (unchanged mechanically):

1. `export CURSOR_API_KEY='...'`
2. `./scripts/run_full_experiment.sh` (or adjust `N_PER_CONDITION` / `N_TOTAL` if design changes)
3. `./scripts/collect_results.sh`
4. `Rscript scripts/analyze_results.R` — may need updates if conditions or hypotheses change.

## TWFE note

**Current root docs** allow **TWFE** alongside Callaway–Sant’Anna-style and related estimators; see `DID_METHODOLOGY.md` (Section 3 for caveats, **Choice of Estimator** for options).

**First wave (frozen in `First Step/`):** Archived `DID_METHODOLOGY.md` included an explicit line not to use TWFE for staggered DiD; that language was removed from the active protocol for later waves.

---

*Last updated to reflect state after the first 150-agent run, `First Step/` archive, and TWFE-allowed instruction revisions.*
