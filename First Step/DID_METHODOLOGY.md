# Difference-in-Differences Methodology Reference
## Based on Baker, Callaway, Cunningham, Goodman-Bacon, and Sant'Anna (2025)

This document summarizes contemporary best practices for difference-in-differences (DiD) estimation with staggered treatment adoption. It is intended as a reference for implementing the Callaway and Sant'Anna (2021) estimator using the R `did` package.

---

## 1. The Target Parameter: ATT

The **average treatment effect on the treated** is:

ATT(t) = E[Y(1) - Y(0) | D = 1]

This is the difference between what happened to treated units and what *would have happened* to them absent treatment. The counterfactual Y(0) for treated units is never observed — it must be identified from assumptions.

---

## 2. Core Identification Assumptions

### No Anticipation (NA)
Treatment does not affect outcomes before it begins. For all pre-treatment periods t < g: Y_{i,t}(g) = Y_{i,t}(0).

### Parallel Trends (PT)
Absent treatment, the average change in outcomes would have been the same for treated and comparison groups:

E[Y(0)_t2 - Y(0)_t1 | D=1] = E[Y(0)_t2 - Y(0)_t1 | D=0]

This is **untestable** because it involves counterfactual outcomes for treated units. Pre-treatment trends are informative but do not test the assumption directly.

### Conditional Parallel Trends (CPT)
When unconditional PT is implausible due to covariate imbalance, a weaker assumption suffices: PT holds *within* each covariate stratum:

E[ΔY(0) | X, D=1] = E[ΔY(0) | X, D=0]

This requires the **strong overlap** condition: 0 < P(D=1|X) < 1.

---

## 3. Why Not TWFE?

The standard two-way fixed effects regression:

Y_{i,t} = θ_t + η_i + β · D_{i,t} + ε_{i,t}

has well-documented problems with staggered adoption:

- It uses **already-treated units** as comparisons, whose outcomes reflect treatment effects.
- The coefficient β is a weighted average of group-time ATTs with potentially **negative weights**.
- β can have the **opposite sign** of the true average treatment effect when effects vary over time.
- These problems extend to TWFE event study specifications.

**Do not use TWFE for staggered DiD.** Use the Callaway and Sant'Anna (2021) estimator or equivalent modern approaches.

---

## 4. Staggered Adoption: Group-Time ATTs

With staggered treatment, define groups by treatment timing:
- G_i = the period when unit i first receives treatment
- G_i = ∞ for never-treated units

The building block parameter is the **group-time ATT**:

ATT(g, t) = E[Y_t(g) - Y_t(∞) | G_i = g]

This is the average effect at time t of starting treatment at g, among units that actually started at g. Each ATT(g,t) is identified as a simple 2x2 DiD.

---

## 5. Comparison Groups and Parallel Trends Variants

Three choices for the comparison group, each requiring a different PT assumption:

| Comparison group | Assumption | Pros | Cons |
|---|---|---|---|
| **Never-treated only** | PT-GT-Nev | Avoids compositional changes; doesn't restrict pre-trends | May be too different from treated; fewer observations |
| **Not-yet-treated** (recommended) | PT-GT-NYT | More data, better precision; doesn't restrict pre-trends | Comparison group changes over time |
| **All groups, all periods** | PT-GT-all | Most precise; uses all available data | Imposes parallel pre-trends (strongest assumption) |

**Recommendation:** Use not-yet-treated comparison groups (PT-GT-NYT) as the default. This is the Callaway and Sant'Anna (2021) approach.

---

## 6. Estimation with Covariates

### Which covariates to include
- Covariates should be variables that (a) predict outcome trends and (b) differ between treated and comparison groups.
- Use **baseline** (pre-treatment) values of covariates, not post-treatment values.
- Post-treatment covariates affected by treatment are "bad controls" — conditioning on them biases estimates.
- Check covariate balance using normalized differences (threshold: ~0.25).

### Three estimation approaches

**Regression Adjustment (RA):** Model the comparison group's outcome trends as a function of covariates, predict counterfactuals for treated units.

**Inverse Probability Weighting (IPW):** Model the probability of treatment given covariates, re-weight comparison units to match the treated group's covariate distribution.

**Doubly Robust (DR) — RECOMMENDED:** Combines RA and IPW. Consistent if *either* model is correctly specified. Use `est_method = "dr"` in the `did` package.

### Propensity score warnings
- IPW and DR become noisy when propensity scores are near 1 among comparison units.
- The `did` package trims comparison units with propensity scores > 0.995 by default.
- Always check overlap by examining the distribution of fitted propensity scores.

---

## 7. Aggregation

Group-time ATTs can be aggregated in several ways:

**Simple ATT:** Weighted average of all post-treatment ATT(g,t), with weights proportional to group size. A single number summarizing the overall effect.

**Event-time aggregation:** ATT_es(e) = weighted average of ATT(g, g+e) across groups at event-time e. Produces the familiar event study plot.

**Balanced event study:** Restrict to groups observed for a minimum number of post-treatment periods to avoid compositional changes across event times.

---

## 8. Event Studies and Pre-trends

### Interpretation
- Post-treatment event study coefficients estimate ATT(t) at each horizon.
- Pre-treatment coefficients measure *differences in pre-treatment trends* between treated and comparison groups. Under NA, these should be zero if PT holds.

### Warnings about pre-trends
1. Pre-trends test a *different* condition than the identifying assumption. PT restricts post-treatment counterfactuals; pre-trends measure pre-treatment differences.
2. Low-powered pre-trend tests can neither confirm nor rule out PT violations.
3. Do not rely solely on the "eye test." Use formal sensitivity analysis (Rambachan and Roth 2023) to bound treatment effects under plausible PT violations.

### Simultaneous inference
- Use **uniform confidence bands** (sup-t), not pointwise confidence intervals, for the event study curve.
- The `did` package produces these by default.

---

## 9. The `did` R Package

### Basic syntax

```r
library(did)

# Estimate group-time ATTs
result <- att_gt(
  yname = "outcome_variable",        # outcome
  tname = "time_variable",           # time period
  idname = "unit_id",                # unit identifier
  gname = "treatment_timing",        # period of first treatment (0 or Inf for never-treated)
  xformla = ~ covariate1 + covariate2,  # covariates (baseline values)
  data = your_data,
  est_method = "dr",                 # doubly robust (recommended)
  control_group = "notyettreated",   # not-yet-treated comparison (recommended)
  base_period = "varying"            # use g-1 as baseline for each group
)

# Aggregate to simple ATT
agg_simple <- aggte(result, type = "simple")

# Aggregate to event study
agg_es <- aggte(result, type = "dynamic")

# Plot event study
ggdid(agg_es)
```

### Key options
- `est_method`: `"dr"` (doubly robust, recommended), `"ipw"`, or `"reg"` (regression adjustment)
- `control_group`: `"notyettreated"` (recommended) or `"nevertreated"`
- `base_period`: `"varying"` (use g-1 for each group, recommended) or `"universal"` (use a single base period)
- `xformla`: formula for covariates. Use baseline (pre-treatment) values only.
- `bstrap`: `TRUE` for bootstrap inference (default). Produces uniform confidence bands.
- `cband`: `TRUE` for simultaneous confidence bands (default).

### Output
- `att_gt` returns group-time ATT estimates with standard errors
- `aggte` aggregates: `type = "simple"` for overall ATT, `type = "dynamic"` for event study, `type = "group"` for group-specific ATTs
- `ggdid` plots the event study with confidence bands

---

## 10. Practical Checklist

1. **Define your treatment timing variable.** Each unit needs a treatment start period (or 0/Inf for never-treated).
2. **Check covariate balance** between treated and comparison groups using normalized differences.
3. **Choose comparison group.** Default: not-yet-treated.
4. **Choose estimation method.** Default: doubly robust (`est_method = "dr"`).
5. **Select covariates.** Use baseline values that predict outcome trends and differ between groups. Avoid post-treatment variables.
6. **Standardize covariates** if they are on very different scales. This prevents numerical instability in the propensity score model.
7. **Estimate group-time ATTs** using `att_gt()`.
8. **Examine the event study** using `aggte(type = "dynamic")`. Check pre-trends. Use uniform confidence bands.
9. **Report the simple ATT** using `aggte(type = "simple")`.
10. **Conduct sensitivity analysis** for plausible parallel trends violations.

---

## 11. Continuous Treatment: The CGBS Framework

When treatment is not binary but **continuous** (a dose), the Callaway, Goodman-Bacon, and Sant'Anna (CGBS) framework extends DiD to estimate dose-response relationships.

### Target Parameter: ATT(d|d)

The average treatment effect on the treated at dose d:

ATT(d|d) = E[Y(d) - Y(0) | D = d]

This is the effect of receiving dose d, among units that actually received dose d. It varies across dose levels — the full set {ATT(d|d)} traces out the dose-response curve.

### Identification

**Parallel Trends (for continuous treatment):** Absent treatment, the average change in outcomes would be the same across all dose levels:

E[ΔY(0) | dose = d] = E[ΔY(0) | dose = 0] for all d > 0

The dose = 0 group provides the counterfactual trend for all treated units, regardless of their dose.

**No Anticipation:** Same as the binary case.

### Estimation Steps

1. **Collapse to 2×2.** Select a pre-treatment period t₀ and post-treatment period t₁. Compute the first-differenced outcome: ΔY = Y_{t₁} - Y_{t₀}.

2. **Estimate the counterfactual trend** from the dose = 0 group:
   E[ΔY | dose = 0] = mean of ΔY among untreated units.

3. **De-trend treated units.** For all units with dose > 0, compute:
   ΔY_adjusted = ΔY - E[ΔY | dose = 0]

4. **Estimate the dose-response function** by regressing ΔY_adjusted on dose, using only treated units (dose > 0). Three common functional forms:

   - **Linear:** `ΔY_adjusted ~ dose` — assumes ATT(d|d) is linear in d
   - **Spline:** `ΔY_adjusted ~ bs(dose)` — flexible nonlinear curve using B-splines
   - **Bins:** `ΔY_adjusted ~ 0 + I(dose < c₁) + I(c₁ ≤ dose < c₂) + I(dose ≥ c₂)` — separate effects per dose bin, no functional form assumption

### Event Study with Continuous Treatment

Repeat the 2×2 procedure for multiple time periods relative to treatment onset:

- For each event time e, form a 2×2 with periods (t₀, t₀ + e)
- Estimate ATT(d|d) at each event time
- Plot the dose-response curve over event time
- Pre-treatment event times should show zero effects if parallel trends holds

### Standard vs. Strong Parallel Trends

**Standard PT** identifies ATT(d|d) — the effect at each dose level. Cross-dose comparisons (e.g., "higher dose → larger effect") mix causal effects with selection bias because units that chose higher doses may differ in unobserved ways.

**Strong PT** additionally assumes no selection on gains. Under strong PT, the slope of the dose-response curve has a purely causal interpretation: the **Average Causal Response to Treatment (ACRT)**. This stronger assumption is not testable beyond standard PT.

### The `contdid` R Package

The `contdid` package provides a unified interface for continuous DiD:

```r
library(contdid)

result <- cont_did(
  yname = "outcome",              # outcome variable name
  tname = "time",                 # time variable (2 periods)
  idname = "unit_id",             # unit identifier
  dname = "dose",                 # continuous dose variable
  gname = "treatment_timing",     # treatment timing variable
  data = panel_data,
  target_parameter = "level",     # "level" for ATT(d|d), "derivative" for ACRT
  aggregation = "dose",           # "dose" or "overall"
  treatment_type = "continuous",
  control_group = "notyettreated" # or "nevertreated"
)

summary(result)
ggcont_did(result, type = "att")  # dose-response plot
```

**Key options:**
- `target_parameter = "level"` estimates ATT(d|d) (requires standard PT only)
- `target_parameter = "derivative"` estimates ACRT (requires strong PT)
- `aggregation = "dose"` gives dose-specific effects; `"overall"` gives a single aggregate

### Manual Estimation (without contdid)

You can also estimate the dose-response manually using `fixest`:

```r
library(fixest)
library(splines)

# Step 1-2: First-difference and counterfactual trend
collapsed <- data |>
  filter(year %in% c(pre_year, post_year)) |>
  summarize(.by = unit_id,
    Delta_Y = outcome[year == post_year] - outcome[year == pre_year],
    dose = dose_variable[year == pre_year])

trend <- mean(collapsed$Delta_Y[collapsed$dose == 0], na.rm = TRUE)

# Step 3-4: De-trend and estimate
est_linear <- feols(I(Delta_Y - trend) ~ dose,
                    collapsed |> filter(dose > 0))
est_spline <- feols(I(Delta_Y - trend) ~ bs(dose),
                    collapsed |> filter(dose > 0))
```

---

## 12. Important: Verifying Results

Some estimators (both `did` and `contdid`) may produce output that appears successful but contains degenerate estimates — for example, ATT estimates of exactly zero with NA standard errors, or convergence warnings buried in output. **Always verify your results manually:**

- Check that ATT estimates are non-trivial (not all exactly zero)
- Check that standard errors are finite and non-NA
- Check for convergence warnings or error messages in the estimation output
- If an estimator fails or produces degenerate results, report this honestly rather than treating zeros as findings

---

## Key References

- Baker, Callaway, Cunningham, Goodman-Bacon, Sant'Anna (2025). "Difference-in-Differences Designs: A Practitioner's Guide."
- Callaway and Sant'Anna (2021). "Difference-in-Differences with Multiple Time Periods." *Journal of Econometrics*.
- Callaway, Goodman-Bacon, and Sant'Anna (2024). "Difference-in-Differences with a Continuous Treatment." Working paper.
- Goodman-Bacon (2021). "Difference-in-Differences with Variation in Treatment Timing." *Econometrica*.
- Roth (2022). "Pretest with Caution: Event-Study Estimates after Testing for Parallel Trends." *AER: Insights*.
- Rambachan and Roth (2023). "A More Credible Approach to Parallel Trends." *Review of Economic Studies*.
- Sant'Anna and Zhao (2020). "Doubly Robust Difference-in-Differences Estimators." *Journal of Econometrics*.
- Sun and Abraham (2021). "Estimating Dynamic Treatment Effects in Event Studies with Heterogeneous Treatment Effects." *Journal of Econometrics*.
