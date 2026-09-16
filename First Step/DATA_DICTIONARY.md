# Data Dictionary: agent_panel_essential.csv

**Structure:** State-by-year panel. 51 units (50 states + DC), 1990--2022. Unit of observation: state-year.

---

## Identifiers

| Column | Description |
|--------|-------------|
| `statefip` | State FIPS code (1--56, with gaps) |
| `year` | Calendar year (1990--2022) |
| `state_name` | Full state name |
| `state_abb` | Two-letter state abbreviation |

## Minimum Wage Variables

Source: Zipperer minimum wage database.

| Column | Description |
|--------|-------------|
| `effective_mw` | Binding minimum wage = max(state MW, federal MW), in dollars |
| `mw_change` | Binary: 1 if effective MW increased from prior year |
| `mw_level_change` | Dollar amount of year-over-year increase in effective MW |
| `mw_pct_change` | Percentage change in effective MW from prior year |

## CPS Employment Outcomes

Source: Current Population Survey, Basic Monthly.

All rates are proportions (0--1 scale). Population counts are CPS-weighted.

### Subgroup suffixes

| Suffix | Definition |
|--------|------------|
| `all` | All persons age 16+ |
| `teen` | Ages 16--19 |
| `young_adult` | Ages 20--24 |
| `prime_age` | Ages 25--54 |
| `lt_hs` | Less than high school education, age 16+ |
| `no_ba` | No bachelor's degree (< HS + HS + some college), age 16+ |
| `male` | Male, age 16+ |
| `female` | Female, age 16+ |
| `teen_male` | Male, ages 16--19 |
| `teen_female` | Female, ages 16--19 |

### Outcome variables

| Pattern | Description | Subgroups present |
|---------|-------------|-------------------|
| `emp_pop_ratio_X` | Employment-to-population ratio | all, teen, young_adult, prime_age, lt_hs, no_ba, male, female, teen_male, teen_female |
| `lfpr_X` | Labor force participation rate | all, teen |
| `unemp_rate_X` | Unemployment rate | all, teen |
| `pop_X` | Population count (CPS-weighted) | all, teen, young_adult, lt_hs, no_ba |
| `n_obs_X` | Unweighted CPS sample size in the cell | all, teen, young_adult |

## QCEW Establishment Data

Source: Quarterly Census of Employment and Wages, BLS. Values are annual averages.

### Industry suffixes

| Suffix | Definition |
|--------|------------|
| `total_private` | All private sector (NAICS ownership code 5) |
| `food_services` | Food services and drinking places (NAICS 722) |
| `retail` | Retail trade (NAICS 44--45) |
| `accommodation_food` | Accommodation and food services (NAICS 72) |

### Outcome variables

| Pattern | Description | Industries present |
|---------|-------------|--------------------|
| `emplvl_X` | Annual average employment level | total_private, food_services, retail, accommodation_food |
| `wkly_wage_X` | Annual average weekly wage (dollars) | total_private, food_services |
