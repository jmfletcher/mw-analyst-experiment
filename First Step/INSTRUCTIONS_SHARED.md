# Minimum Wage and Employment: An Empirical Analysis

You are a labor economist conducting an empirical study of the effect of minimum wage increases on employment in the United States. Your task is to estimate the causal effect using modern difference-in-differences methods on a state-level panel dataset.

## Your Research Question

**Does increasing the minimum wage affect employment?**

You have full discretion over how to operationalize this question. You will decide:
- Which employment measure to study
- How to define treatment
- Which years and states to include
- Which covariates (if any) to condition on
- Which estimator to use
- How to aggregate and report results

## Data

You have been provided with `agent_panel_essential.csv`, a state-by-year panel covering 51 US states and DC from 1990 to 2022. See `DATA_DICTIONARY.md` for variable descriptions.

The dataset contains:
- **Minimum wage variables:** Effective minimum wage (max of state and federal), binary and continuous change indicators
- **CPS employment outcomes:** Employment-to-population ratios, labor force participation rates, and unemployment rates for multiple demographic subgroups (all workers, teens, young adults, prime age, by education, by sex)
- **QCEW establishment data:** Average employment levels and weekly wages for selected industries (total private, food services, retail, accommodation and food, construction, manufacturing)
- **Population counts:** For constructing weights or assessing cell sizes

## Methodology

Read `DID_METHODOLOGY.md` carefully. It covers:
- The Callaway and Sant'Anna (2021) estimator for binary staggered treatment (`did` R package)
- The Callaway, Goodman-Bacon, and Sant'Anna continuous treatment framework (`contdid` R package)
- Identification assumptions, comparison group choices, covariate selection, aggregation, and event studies

Both the `did` and `contdid` R packages are pre-installed and available for use, along with `ggplot2`, `dplyr`, and `tidyr`.

## Deliverables

You must produce exactly two output files in your working directory:

### 1. `results.csv`

A single-row CSV with these columns:

```
agent_id, outcome_variable, treatment_definition, estimator, control_group, covariates, years_start, years_end, n_states, n_periods, att_estimate, att_se, att_pvalue, att_ci_lower, att_ci_upper, event_study_produced, notes
```

- `agent_id`: Your assigned agent number (provided at runtime)
- `outcome_variable`: The dependent variable you chose (e.g., "emp_pop_ratio_teen")
- `treatment_definition`: "binary" or "continuous"
- `estimator`: "callaway_santanna" or "cgbs_continuous" or other description
- `control_group`: "notyettreated" or "nevertreated"
- `covariates`: Comma-separated list of covariates used, or "none"
- `years_start`, `years_end`: The time range of your analysis
- `n_states`, `n_periods`: Sample dimensions
- `att_estimate`: Your primary ATT point estimate
- `att_se`: Standard error
- `att_pvalue`: p-value
- `att_ci_lower`, `att_ci_upper`: 95% confidence interval bounds
- `event_study_produced`: "yes" or "no"
- `notes`: Any brief notes about estimation issues, convergence, or diagnostics

### 2. `llms.txt`

A structured summary of your analysis following this format:

```
# Minimum Wage and Employment: [Your Specific Title]

> Agent [N] analysis of minimum wage effects on [outcome]

## Research Design

[1-2 paragraphs: What outcome did you study? How did you define treatment? Why?]

## Data and Sample

[1 paragraph: Which years, states, and subpopulations? Any sample restrictions?]

## Estimation

[1-2 paragraphs: Which estimator? Comparison group? Covariates? Base period?]

## Results

[1-2 paragraphs: What did you find? Report the primary ATT with standard errors and confidence intervals. Describe the event study if produced.]

## Diagnostics

[1 paragraph: Pre-trends? Sensitivity checks? Any estimation issues?]

## Limitations and Scope

[1 paragraph: What are the limitations of your analysis? What would you do differently with more time/data?]
```

## Your Approach

You are a researcher, not a technician. Think carefully about your choices before writing code:

- **Explore the data first.** Read `DATA_DICTIONARY.md` carefully before writing any code. Understand what variables are available and what they measure.
- **Justify your decisions.** Why this outcome variable and not another? Why this sample period? Why this treatment definition? Every choice should have a reason grounded in economic logic, data quality, or methodological considerations. Document your reasoning in the llms.txt.
- **Be thorough.** Check your results. Examine the event study. Look at pre-trends. Consider whether your findings are robust or fragile. A good empirical analysis anticipates objections.
- **Do not give up if your first specification fails.** Estimation errors are common in DiD — they usually mean your treatment definition, sample, or comparison group needs adjustment. If `att_gt()` or `cont_did()` throws an error or produces degenerate results (all-zero ATTs, NA standard errors), diagnose the problem and try a different approach. Common fixes include: narrowing the sample period, changing the treatment definition, switching between never-treated and not-yet-treated comparison groups, dropping small treatment cohorts, or trying the continuous treatment framework instead of binary (or vice versa). Iterate until you have valid, non-degenerate estimates. A failed estimation is not an acceptable final result unless you have genuinely exhausted all reasonable alternatives and documented each attempt.
- **If after multiple attempts you still cannot produce valid estimates**, report your best attempt honestly, explain what went wrong, and describe what you tried in both deliverables.

## Technical Notes

- Write your analysis as a self-contained R script. All code should be reproducible.
- Save `results.csv` and `llms.txt` to your working directory.
- You have full discretion over specification choices. Make defensible decisions and document your reasoning.
