# Minimum Wage Many-Analyst Experiment

An experiment testing whether AI agents' prompted priors about the minimum wage causally affect their empirical findings.

## Design

150 autonomous Cursor agents analyze the same state-level panel data on minimum wages and employment using difference-in-differences methods. Agents are assigned to five treatment conditions, configured in `conditions.tsv`:

- **None**: no literature context
- **Null Short**: brief null or near-zero employment-effect prime
- **Null Cites**: citation-rich null or near-zero employment-effect prime
- **Negative Short**: brief negative employment-effect prime
- **Negative Cites**: citation-rich negative employment-effect prime

Each agent receives identical data, methodology documentation, and task instructions. The only variation is the literature context file, when a condition has one. Agents have full discretion over outcome variable, sample period, treatment definition, control group, and estimator.

## Inspired By

Borjas & Breznau (2026, *Science Advances*), which found that immigration researchers' prior beliefs predicted their empirical estimates through specification choices. This design randomizes the prior via prompt, making it an experiment.

## Data

Pre-aggregated CPS and QCEW state-level annual panel (51 states, 1990-2022). Includes teen employment, young adult employment, low-education employment, and food services employment outcomes alongside minimum wage histories.

## Running the Experiment

See `RUN_INSTRUCTIONS.md` for setup, usage, and cost/time estimates.

```bash
npm install
export CURSOR_API_KEY="cursor_..."
./scripts/run_full_experiment.sh
./scripts/collect_results.sh
Rscript scripts/analyze_results.R
```

## Repository Structure

```text
├── data/
│   └── agent_panel_essential.csv
├── scripts/
│   ├── launch_experiment_cursor.mjs
│   ├── run_pilot_one_per_condition.sh
│   ├── run_full_experiment.sh
│   ├── launch_experiment.sh
│   ├── collect_results.sh
│   └── analyze_results.R
├── conditions.tsv
├── INSTRUCTIONS_SHARED.md
├── DATA_DICTIONARY.md
├── DID_METHODOLOGY.md
├── PRIME_NULL_SHORT.md
├── PRIME_NULL_CITES.md
├── PRIME_NEGATIVE_SHORT.md
├── PRIME_NEGATIVE_CITES.md
└── RUN_INSTRUCTIONS.md
```

## Author

Scott Cunningham, Baylor University
