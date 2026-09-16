# Re: Raw files from the Opus 4.6 run

Scott —

Attached is everything: **`mw_experiment_raw_results.zip`** (9.2 MB). It contains the full raw per-agent output from all three model runs, not just Opus.

## What's in the zip

### Per-agent files (all five arms × 50 agents per arm, per model)

| Run | Dir in zip | Agents | `results.csv` | `llms.txt` | `agent_log.txt` | `analysis.R` |
|-----|-----------|--------|---------------|-----------|-----------------|-------------|
| **Composer-2** (baseline) | `Second Step/results/` | 250 | 250 | 250 | 250 | varies |
| **Opus 4.6** | `Third Step/results_opus46/` | 250 | 249 | 244 | 250 | 237 |
| **Grok 4.6** | `Third Step/results_grok46/` | 250 | 245 | 245 | 250 | varies |

Each agent directory (e.g. `arm_none/none_001/`) contains:

- **`results.csv`** — one-row CSV with outcome, treatment definition, estimator, control group, covariates, sample window, ATT estimate, SE, p-value, CI
- **`llms.txt`** — the agent's structured narrative of its design choices and interpretation
- **`agent_log.txt`** — SDK session transcript (tool calls, R output, reasoning)
- **`analysis.R`** — the R script the agent wrote and executed (some agents wrote multiple R files for robustness checks)

### Combined results

- `Second Step/results/results_all.csv` — all 250 Composer-2 rows
- `Third Step/results_opus46/results_all.csv` — all 249 Opus 4.6 rows
- `Third Step/results_grok46/results_all.csv` — all 245 Grok 4.6 rows

### Protocol documents (same across all runs)

- `conditions.tsv` — the five arm definitions
- `INSTRUCTIONS_SHARED.md` — task instructions each agent received
- `DID_METHODOLOGY.md` — the methodology reference
- `DATA_DICTIONARY.md` — variable descriptions
- `PRIME_NEGATIVE_SHORT.md`, `PRIME_NEGATIVE_CITES.md`, `PRIME_NULL_SHORT.md`, `PRIME_NULL_CITES.md` — the four literature primes

### Reports

- `reports/project_executive_summary.pdf` — executive summary with cross-model comparison
- `reports/cursor_replication_report.pdf` — full technical replication report

## Headline results across models

| Model | N | Fisher *p* | KW *p* | Negative-arm shift? | Mechanism |
|-------|---|-----------|--------|--------------------|-----------| 
| **Composer-2** | 250 | 0.41 | 0.31 | No | — |
| **Opus 4.6** | 249 | **0.001** | **0.007** | `negative_short` only | Estimator choice (TWFE/CGBS/continuous) |
| **Grok 4.6** | 245 | **<0.0001** | **7×10⁻¹²** | Both negative arms | Outcome variable + control group choice |

The most interesting finding: **the mechanism through which priors affect estimates varies by model.** Opus shifts through estimator/treatment specification (closer to your Wave 2 pattern); Grok shifts through outcome and comparison-group selection while staying entirely on Callaway–Sant'Anna.

## Arm mapping to yours

Our five arms map to your three as follows:

| Your arm | Our arms |
|----------|----------|
| Control (No Context) | `none` |
| Null Context | `null_short` + `null_cites` |
| Negative Context | `negative_short` + `negative_cites` |

The short/cites split lets you test whether citation density matters. In Grok 4.6, `negative_short` shows the strongest effect; in Opus 4.6, same pattern. The cites variants are generally weaker, which is interesting.

## Notes

- The `results.csv` schema matches yours (same columns from `INSTRUCTIONS_SHARED.md`).
- One Opus 4.6 agent (`negative_cites_039`) and five Grok 4.6 agents failed to produce `results.csv` — their `agent_log.txt` files are still included for inspection.
- Agent logs contain the full SDK session transcript including R output, so you can see exactly what each agent tried and why.
- The repo is at [github.com/jmfletcher/mw-analyst-experiment](https://github.com/jmfletcher/mw-analyst-experiment) — code and protocol files are there; raw results are gitignored due to size but fully in this zip.

Happy to dig into any specific agents or re-run with different parameters. Looking forward to the cross-platform comparison.

— Jason
