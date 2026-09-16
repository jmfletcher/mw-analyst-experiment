#!/usr/bin/env Rscript
# Extended analysis for second-wave results under Second Step/results.
#
# Usage (from repo root):
#   Rscript scripts/analyze_second_step_detail.R
#   Rscript scripts/analyze_second_step_detail.R "Second Step/results" "Second Step/analysis"

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
})

args <- commandArgs(trailingOnly = TRUE)
results_dir <- if (length(args) >= 1) args[[1]] else "Second Step/results"
analysis_dir <- if (length(args) >= 2) args[[2]] else "Second Step/analysis"
dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)

results_path <- file.path(results_dir, "results_all.csv")
if (!file.exists(results_path)) {
  stop("Missing ", results_path, call. = FALSE)
}

conditions <- read.delim("conditions.tsv", stringsAsFactors = FALSE, na.strings = "")
condition_levels <- conditions$condition

results <- read.csv(results_path, stringsAsFactors = FALSE) |>
  mutate(
    arm = sub("_[0-9]+$", "", agent_id),
    arm = factor(arm, levels = condition_levels),
    estimator_lc = tolower(trimws(as.character(estimator))),
    est_family = case_when(
      grepl("twfe|fixest|feols|^fe |plm|lfe|within", estimator_lc) ~ "twfe_like",
      grepl("callaway|att_gt|did::|did package|sant.?anna", estimator_lc) ~ "callaway_santanna_family",
      grepl("cont.?did|cgbs|continuous", estimator_lc) ~ "continuous_did",
      grepl("^sun|sun_abraham", estimator_lc) ~ "other_modern",
      estimator_lc == "" | is.na(estimator_lc) ~ "unspecified",
      TRUE ~ "other"
    ),
    event_yes = tolower(trimws(as.character(event_study_produced))) %in% c("yes", "y", "true", "1"),
    years_start = suppressWarnings(as.integer(years_start)),
    years_end = suppressWarnings(as.integer(years_end)),
    year_span = years_end - years_start + 1,
    n_periods = suppressWarnings(as.numeric(n_periods)),
    att_estimate = as.numeric(att_estimate),
    att_se = suppressWarnings(as.numeric(att_se))
  )

sink(file.path(analysis_dir, "session_log.txt"), split = TRUE)
on.exit(sink(), add = TRUE)

cat("=== Second Step — detailed analysis ===\n")
cat(sprintf("Results: %s\nAnalysis output: %s\n\n", results_path, analysis_dir))

cat("=== Sample sizes ===\n")
print(table(results$arm, useNA = "always"))
cat("\n")

# ----------------------------------------------------------------------------
# Arm-level ATT summary
# ----------------------------------------------------------------------------
arm_summary <- results |>
  filter(!is.na(att_estimate)) |>
  group_by(arm) |>
  summarize(
    n = n(),
    mean_att = mean(att_estimate),
    sd_att = sd(att_estimate),
    se_mean = sd_att / sqrt(n),
    median_att = median(att_estimate),
    q25 = quantile(att_estimate, 0.25),
    q75 = quantile(att_estimate, 0.75),
    frac_negative = mean(att_estimate < 0, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    t_vs_0 = mean_att / se_mean,
    p_vs_0 = 2 * pnorm(-abs(t_vs_0))
  )

write.csv(arm_summary, file.path(analysis_dir, "arm_level_att_summary.csv"), row.names = FALSE)
cat("=== ATT by arm (mean, SD, one-sample z on mean) ===\n")
print(as.data.frame(arm_summary), row.names = FALSE)
cat("\n")

# ----------------------------------------------------------------------------
# OLS: ATT ~ arm (reference = none)
# ----------------------------------------------------------------------------
dd <- results |> filter(!is.na(att_estimate), !is.na(arm))
dd$arm <- relevel(dd$arm, ref = "none")
fit <- lm(att_estimate ~ arm, data = dd)
cat("=== Linear model: att_estimate ~ arm (reference arm = none) ===\n")
print(summary(fit))
cat("\n")

cf <- coef(fit)
vc <- vcov(fit)
pn <- names(cf)

get_contrast_se <- function(w) {
  w <- w[abs(w) > 1e-12 & !is.na(w)]
  keep <- names(w)[names(w) %in% colnames(vc)]
  if (length(keep) < 1) {
    return(NA_real_)
  }
  a <- w[keep]
  vv <- vc[keep, keep, drop = FALSE]
  sqrt(as.numeric(t(a) %*% vv %*% a))
}

w_short <- rep(0, length(cf))
names(w_short) <- pn
w_short["armnull_short"] <- 1
w_short["armnegative_short"] <- -1

w_cites <- rep(0, length(cf))
names(w_cites) <- pn
w_cites["armnull_cites"] <- 1
w_cites["armnegative_cites"] <- -1

w_pool <- rep(0, length(cf))
names(w_pool) <- pn
w_pool["armnull_short"] <- 0.5
w_pool["armnull_cites"] <- 0.5
w_pool["armnegative_short"] <- -0.5
w_pool["armnegative_cites"] <- -0.5

lin_contrasts <- data.frame(
  contrast = c(
    "null_short - negative_short",
    "null_cites - negative_cites",
    "mean(null_arms_vs_none) - mean(negative_arms_vs_none)"
  ),
  estimate = c(
    sum(cf * w_short),
    sum(cf * w_cites),
    sum(cf * w_pool)
  ),
  stringsAsFactors = FALSE
)

lin_contrasts$se <- c(
  get_contrast_se(w_short),
  get_contrast_se(w_cites),
  get_contrast_se(w_pool)
)

lin_contrasts <- lin_contrasts |>
  mutate(
    z = estimate / se,
    p_two_sided = 2 * pnorm(-abs(z))
  )

write.csv(lin_contrasts, file.path(analysis_dir, "planned_linear_contrasts.csv"), row.names = FALSE)
cat("=== Pre-spec-style linear contrasts (from lm with ref = none) ===\n")
print(lin_contrasts, row.names = FALSE)
cat("\n")

# ----------------------------------------------------------------------------
# Estimator family × arm
# ----------------------------------------------------------------------------
est_tab <- results |>
  count(arm, est_family) |>
  mutate(prop = n / sum(n), .by = arm)

write.csv(est_tab, file.path(analysis_dir, "estimator_family_by_arm.csv"), row.names = FALSE)
cat("=== Estimator family counts by arm ===\n")
print(as.data.frame(est_tab), row.names = FALSE)
cat("\n")

if (length(unique(results$est_family)) > 1) {
  cat("Chi-squared: est_family ~ arm\n")
  print(chisq.test(table(results$arm, results$est_family), simulate.p.value = TRUE, B = 10000))
  cat("\n")
}

# ----------------------------------------------------------------------------
# Design choices: event study, years, treatment definition
# ----------------------------------------------------------------------------
cat("=== Event study produced (yes rate by arm) ===\n")
evt_rate <- results |>
  group_by(arm) |>
  summarize(
    n = n(),
    frac_event_study = mean(event_yes, na.rm = TRUE),
    .groups = "drop"
  )
print(as.data.frame(evt_rate), row.names = FALSE)
write.csv(evt_rate, file.path(analysis_dir, "event_study_rate_by_arm.csv"), row.names = FALSE)
cat("\n")

td_tab <- results |> count(arm, treatment_definition)
write.csv(td_tab, file.path(analysis_dir, "treatment_definition_by_arm.csv"), row.names = FALSE)
cat("=== Treatment definition by arm ===\n")
print(as.data.frame(td_tab), row.names = FALSE)
cat("\n")

cat("=== Sample window (years) ===\n")
yr_s <- results |>
  filter(!is.na(year_span)) |>
  group_by(arm) |>
  summarize(
    mean_span = mean(year_span, na.rm = TRUE),
    sd_span = sd(year_span, na.rm = TRUE),
    mean_n_periods_reported = mean(n_periods, na.rm = TRUE),
    .groups = "drop"
  )
print(as.data.frame(yr_s), row.names = FALSE)
write.csv(yr_s, file.path(analysis_dir, "sample_window_by_arm.csv"), row.names = FALSE)
cat("\n")

# ----------------------------------------------------------------------------
# Pairwise arm comparisons (Wilcoxon, BH)
# ----------------------------------------------------------------------------
cat("=== Pairwise Wilcoxon (ATT), BH adjustment ===\n")
print(pairwise.wilcox.test(results$att_estimate, results$arm, p.adjust.method = "BH"))
cat("\n")

# ----------------------------------------------------------------------------
# Permutation omnibus (between-arm SS)
# ----------------------------------------------------------------------------
between_arm_ss <- function(values, arms) {
  arms <- droplevels(as.factor(arms))
  overall_mean <- mean(values, na.rm = TRUE)
  arm_means <- tapply(values, arms, mean, na.rm = TRUE)
  arm_counts <- table(arms)
  sum(arm_counts[names(arm_means)] * (arm_means - overall_mean)^2)
}

complete_results <- results |> filter(!is.na(att_estimate), !is.na(arm))
set.seed(42)
n_perms <- 10000
observed_stat <- between_arm_ss(complete_results$att_estimate, complete_results$arm)
perm_stats <- replicate(n_perms, {
  permuted_arm <- sample(complete_results$arm)
  between_arm_ss(complete_results$att_estimate, permuted_arm)
})
omnibus_p <- mean(perm_stats >= observed_stat)
cat(sprintf("=== Fisher-style omnibus: between-arm SS | p = %.4f (n_perm = %d) ===\n\n", omnibus_p, n_perms))

perm_df <- data.frame(statistic = perm_stats)
p_perm <- ggplot(perm_df, aes(x = statistic)) +
  geom_histogram(bins = 50, fill = "gray75", color = "white") +
  geom_vline(xintercept = observed_stat, color = "#c0392b", linewidth = 1) +
  labs(
    title = "Permutation null for between-arm dispersion of mean ATT",
    subtitle = sprintf("Observed = %.5f, one-sided p = %.4f", observed_stat, omnibus_p),
    x = "Test statistic", y = "Count"
  ) +
  theme_minimal()
ggsave(file.path(analysis_dir, "omnibus_permutation_detail.png"), p_perm, width = 8, height = 5, dpi = 300)

# ----------------------------------------------------------------------------
# Forest plot: arm means ± 1.96 * SE(mean)
# ----------------------------------------------------------------------------
forest <- arm_summary |>
  mutate(
    lo = mean_att - 1.96 * se_mean,
    hi = mean_att + 1.96 * se_mean,
    arm_ord = reorder(as.factor(as.character(arm)), mean_att)
  )

p_forest <- ggplot(forest, aes(x = mean_att, y = arm_ord)) +
  geom_vline(xintercept = 0, linetype = 2, color = "gray50") +
  geom_errorbar(
    aes(xmin = lo, xmax = hi),
    orientation = "y",
    width = 0.2,
    linewidth = 0.5
  ) +
  geom_point(size = 2.5, color = "#2980b9") +
  labs(
    x = "Mean ATT across agents (95% CI for mean)",
    y = NULL,
    title = "Second Step: arm-level mean ATT"
  ) +
  theme_minimal()
ggsave(file.path(analysis_dir, "forest_arm_means.png"), p_forest, width = 8, height = 5, dpi = 300)

p_violin <- ggplot(results, aes(x = arm, y = att_estimate, fill = arm)) +
  geom_hline(yintercept = 0, linetype = 2, color = "gray40") +
  geom_violin(alpha = 0.55, color = NA) +
  geom_jitter(width = 0.15, alpha = 0.35, size = 1.2) +
  labs(
    title = "Distribution of agent-level ATT estimates",
    x = NULL, y = "ATT"
  ) +
  theme_minimal() +
  theme(legend.position = "none", axis.text.x = element_text(angle = 25, hjust = 1))
ggsave(file.path(analysis_dir, "att_violin_by_arm.png"), p_violin, width = 9, height = 5.5, dpi = 300)

p_est <- ggplot(results, aes(x = arm, fill = est_family)) +
  geom_bar(position = "fill") +
  labs(
    title = "Estimator family mix by condition",
    x = NULL, y = "Proportion",
    fill = "Estimator\nfamily"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1))
ggsave(file.path(analysis_dir, "estimator_family_stacked_by_arm.png"), p_est, width = 9, height = 5, dpi = 300)

cat(sprintf("\nFigures and tables written to %s/\n", analysis_dir))
cat("Done.\n")