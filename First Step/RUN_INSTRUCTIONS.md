# Full Experiment Run Instructions

## What This Does

Launches 150 autonomous Cursor agents to analyze the effect of minimum wage on employment. The current design has 5 conditions with 30 agents per condition:

- **None**: No literature priming
- **Null Short**: Brief prime describing literature finding little to no employment effect
- **Null Cites**: Citation-rich prime describing literature finding little to no employment effect
- **Negative Short**: Brief prime describing literature finding negative employment effects
- **Negative Cites**: Citation-rich prime describing literature finding negative employment effects

The condition list is controlled by `conditions.tsv`. Edit that file and the referenced `PRIME_*.md` files if you want different conditions.

Each agent receives the same data, data dictionary, methodology reference, and task instructions. Primed conditions also receive one literature context file. Each agent produces `results.csv` and `llms.txt`.

## Setup

### 1. Install R

```bash
brew install r
Rscript --version
```

### 2. Install R Packages

```bash
Rscript -e 'install.packages(c("did", "contdid", "ggplot2", "dplyr", "tidyr", "fixest"), repos="https://cran.r-project.org")'
Rscript -e 'library(did); library(contdid); library(ggplot2); library(dplyr); library(tidyr); cat("All packages OK\n")'
```

### 3. Install Node and Dependencies

```bash
brew install node
node --version
npm --version
npm install
```

If Terminal says `node: command not found` but Homebrew is installed, your PATH may omit Homebrew. Apple Silicon Macs usually need `/opt/homebrew/bin`; Intel Macs often use `/usr/local/bin`. Add to `~/.zshrc`:

```bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
```

Then run `source ~/.zshrc` or open a new terminal window.

### 4. Configure Cursor SDK Auth

Create a Cursor API key from the Cursor dashboard, then export it before launching:

```bash
export CURSOR_API_KEY="cursor_..."
```

The runner uses the Cursor SDK local runtime, so each agent runs on this machine in its own `/tmp/mw_agent_*` workspace.

## Running the Experiment

From the repository root:

```bash
npm run launch:cursor
```

Or from `scripts/`:

```bash
./launch_experiment.sh
```

Defaults:

- `N_TOTAL=150`
- `N_PER_CONDITION=30` inferred from 150 / 5
- `CONCURRENCY=10`
- `LAUNCH_DELAY_MS=5000`
- `CURSOR_MODEL=composer-2`

Example pilot:

```bash
N_PER_CONDITION=1 CONCURRENCY=2 LAUNCH_DELAY_MS=1000 npm run launch:cursor
```

Same pilot with prerequisite checks (recommended first run):

```bash
export CURSOR_API_KEY="cursor_..."
chmod +x scripts/run_pilot_one_per_condition.sh
./scripts/run_pilot_one_per_condition.sh
```

### Full run (150 agents = 5 conditions x 30)

Uses **`N_TOTAL=150`** and **`N_PER_CONDITION=30`** so a leftover **`N_PER_CONDITION=1`** from a pilot in the same terminal cannot shrink the run.

```bash
export CURSOR_API_KEY='crsr_...'
chmod +x scripts/run_full_experiment.sh
./scripts/run_full_experiment.sh
```

Defaults: **`CONCURRENCY=10`**, **`LAUNCH_DELAY_MS=5000`** (~12.5 minutes just to stagger starts; agents then run in parallel). On Ultra you can try **`CONCURRENCY=15`** and **`LAUNCH_DELAY_MS=3000`** if stable.

Example faster full run (if your machine and account limits tolerate it):

```bash
CONCURRENCY=20 LAUNCH_DELAY_MS=2500 ./scripts/run_full_experiment.sh
```

## Monitor Progress

```bash
ls "$TMPDIR"/mw_agent_*/results.csv 2>/dev/null | wc -l
ls /tmp/mw_agent_*/results.csv 2>/dev/null | wc -l
```

On macOS, Node usually writes under **`$TMPDIR`** (not `/tmp`). The collector checks **`$TMPDIR`**, `/tmp`, and `/private/tmp`.

Check incomplete agents:

```bash
for d in /tmp/mw_agent_*/; do
    if [ ! -f "$d/results.csv" ]; then
        echo "INCOMPLETE: $(basename "$d")"
    fi
done
```

Inspect a log:

```bash
less /tmp/mw_agent_negative_short_001/agent_log.txt
```

## Collect Results

```bash
./scripts/collect_results.sh
```

This produces:

- `output/results_all.csv`
- `output/arm_*/agent_*/results.csv`
- `output/arm_*/agent_*/llms.txt`
- `output/arm_*/agent_*/agent_log.txt`

## Analyze Results

```bash
Rscript scripts/analyze_results.R
```

The analysis now supports any number of conditions listed in `conditions.tsv`. It reports an omnibus Fisher randomization test across all conditions, planned `Null Short` vs. `Negative Short` and `Null Cites` vs. `Negative Cites` contrasts when present, Kruskal-Wallis and pairwise Wilcoxon tests, and specification-choice summaries.

## Usage and Time Estimates

These are planning estimates, not guarantees. Actual usage depends on how much each agent explores, how many failed specifications it debugs, and how much R output it feeds back into the model.

For 150 agents on Cursor's metered agent usage, a reasonable planning range is:

- **Lean run**: about 20-40 dollars, if agents converge quickly
- **Likely run**: about 50-100 dollars
- **Heavy/debuggy run**: about 150-250 dollars, if many agents iterate through failed models

With the default `CONCURRENCY=10` and `LAUNCH_DELAY_MS=5000`, expect roughly **2-4 hours**. With `CONCURRENCY=25` and a shorter launch delay, expect roughly **1-3 hours**, subject to account limits and local CPU/R memory pressure. A one-agent-per-condition pilot should finish in **10-30 minutes**.

## Troubleshooting

**401 / `AuthenticationError` on `GET /v1/models`**: The Cursor API rejected your key. This is not your Ultra subscription login by itself — you need a **User API key** for the **Agents / Cursor API** (not an Anthropic or OpenAI key).

1. Create a new key in the dashboard (UI moves occasionally; try both):
   - [Cloud Agents](https://cursor.com/dashboard/cloud-agents)
   - [Integrations](https://cursor.com/dashboard/integrations) (if “API keys” or “User API keys” live there now)

2. Export the **full** value Cursor shows when you **create** the key (you often cannot see it again later).

```bash
export CURSOR_API_KEY="paste_the_full_key_here"
npm run verify:cursor
```

3. Read the script output: it calls `Cursor.me` first, then `models.list`. If it still fails, the key is still wrong for the API.

Common mistakes: placeholder `cursor_...`, **Admin** or **team** secret used where a **user** agent API key is required, expired/revoked key, or a bad paste (extra spaces — the script trims one; re-copy from a plain-text field).

**Missing `CURSOR_API_KEY` or other auth errors**: Export a valid key in the terminal before launching.

**NetworkError / ByteString / "character 8216"**: A **Unicode character** (often a **curly quote** `' '` U+2018) ended up in `CURSOR_API_KEY` or another header value. HTTP headers must be ASCII. Fix: create the key again, paste into Terminal with **straight ASCII quotes** only:

```bash
export CURSOR_API_KEY='crsr_your_key_here'
```

The launch and verify scripts normalize the key (strip smart quotes and non-ASCII); re-run `npm run verify:cursor` then the pilot.

**Rate limiting or many startup failures**: Lower `CONCURRENCY` and increase `LAUNCH_DELAY_MS`.

**Local machine overload**: Lower `CONCURRENCY`. Each agent may run R jobs and read the same dataset.

**Agent produced no `results.csv`**: Check `/tmp/mw_agent_<condition>_<id>/agent_log.txt`. Common causes are R package issues, estimator failures, or account/rate limits.

**Changing conditions**: Edit `conditions.tsv`; leave `context_file` blank for a no-prime condition.
