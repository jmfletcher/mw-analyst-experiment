#!/usr/bin/env Rscript
# analyze_results.R - Post-experiment analysis of many-analyst results
#
# Reads: output/results_all.csv (combined from collect_results.sh)
# Produces: randomization tests, summary statistics, specification analysis
#
# Usage: Rscript scripts/analyze_results.R

library(dplyr)
library(tidyr)
library(ggplot2)

between_arm_ss <- function(values, arms) {
  arms <- droplevels(as.factor(arms))
  overall_mean <- mean(values, na.rm = TRUE)
  arm_means <- tapply(values, arms, mean, na.rm = TRUE)
  arm_counts <- table(arms)
  sum(arm_counts[names(arm_means)] * (arm_means - overall_mean)^2)
}

run_pair_contrast <- function(results, left_arm, right_arm, left_label, right_label, n_perms = 10000) {
  if (!all(c(left_arm, right_arm) %in% results$arm)) {
    return(invisible(NULL))
  }

  cat(sprintf("=== Planned Contrast: %s vs. %s ===\n", left_label, right_label))
  contrast_data <- results |>
    filter(arm %in% c(left_arm, right_arm), !is.na(att_estimate)) |>
    mutate(arm = droplevels(arm))

  observed_diff <- mean(contrast_data$att_estimate[contrast_data$arm == left_arm]) -
    mean(contrast_data$att_estimate[contrast_data$arm == right_arm])

  n_left <- sum(contrast_data$arm == left_arm)
  contrast_values <- contrast_data$att_estimate

  perm_diffs <- replicate(n_perms, {
    perm_idx <- sample(length(contrast_values), n_left)
    mean(contrast_values[perm_idx]) - mean(contrast_values[-perm_idx])
  })

  contrast_p <- mean(abs(perm_diffs) >= abs(observed_diff))
  cat(sprintf("Observed difference (%s - %s): %.4f\n", left_label, right_label, observed_diff))
  cat(sprintf("Fisher p-value (two-sided, %d permutations): %.4f\n", n_perms, contrast_p))
  cat("\n")
}

# ============================================================================
# Load data
# ============================================================================
results <- read.csv("output/results_all.csv", stringsAsFactors = FALSE)
conditions <- read.delim("conditions.tsv", stringsAsFactors = FALSE, na.strings = "")
condition_levels <- conditions$condition

# Extract condition from agent_id (e.g., "null_short_001" -> "null_short")
results <- results |>
  mutate(
    arm = sub("_[0-9]+$", "", agent_id),
    arm = factor(arm, levels = condition_levels)
  )

cat("=== Sample Sizes ===\n")
print(table(results$arm))
cat("\n")

# ============================================================================
# 1. Summary statistics by condition
# ============================================================================
cat("=== ATT Summary by Condition ===\n")
arm_summary <- results |>
  group_by(arm) |>
  summarize(
    n = n(),
    mean_att = mean(att_estimate, na.rm = TRUE),
    sd_att = sd(att_estimate, na.rm = TRUE),
    median_att = median(att_estimate, na.rm = TRUE),
    min_att = min(att_estimate, na.rm = TRUE),
    max_att = max(att_estimate, na.rm = TRUE),
    .groups = "drop"
  )
print(arm_summary)
cat("\n")

# ============================================================================
# 2. Primary analysis: omnibus Fisher randomization test
# ============================================================================
cat("=== Omnibus Fisher Randomization Test ===\n")
cat("H0 (sharp null): Permuting condition labels does not change ATT distribution\n")
cat("Test statistic: Between-condition sum of squares in mean ATT\n\n")

complete_results <- results |>
  filter(!is.na(att_estimate), !is.na(arm))

set.seed(42)
n_perms <- 10000
observed_stat <- between_arm_ss(complete_results$att_estimate, complete_results$arm)

perm_stats <- replicate(n_perms, {
  permuted_arm <- sample(complete_results$arm)
  between_arm_ss(complete_results$att_estimate, permuted_arm)
})

omnibus_p <- mean(perm_stats >= observed_stat)
cat(sprintf("Observed statistic: %.4f\n", observed_stat))
cat(sprintf("Fisher p-value (%d permutations): %.4f\n", n_perms, omnibus_p))
cat("\n")

run_pair_contrast(results, "null_short", "negative_short", "Null Short", "Negative Short", n_perms)
run_pair_contrast(results, "null_cites", "negative_cites", "Null Cites", "Negative Cites", n_perms)

# ============================================================================
# 3. Secondary: Kruskal-Wallis across all conditions
# ============================================================================
cat("=== Kruskal-Wallis Test (all conditions) ===\n")
kw_test <- kruskal.test(att_estimate ~ arm, data = results)
print(kw_test)
cat("\n")

# ============================================================================
# 4. Pairwise comparisons
# ============================================================================
cat("=== Pairwise Wilcoxon Tests ===\n")
pairwise <- pairwise.wilcox.test(
  results$att_estimate,
  results$arm,
  p.adjust.method = "BH"
)
print(pairwise)
cat("\n")

# ============================================================================
# 5. Specification channel analysis
# ============================================================================
cat("=== Specification Choices by Condition ===\n\n")

cat("Outcome variable:\n")
print(table(results$arm, results$outcome_variable))
cat("\n")

cat("Treatment definition:\n")
print(table(results$arm, results$treatment_definition))
cat("\n")

cat("Estimator:\n")
print(table(results$arm, results$estimator))
cat("\n")

cat("Control group:\n")
print(table(results$arm, results$control_group))
cat("\n")

# Chi-squared tests for specification independence
cat("Chi-squared test: outcome_variable ~ arm\n")
if (length(unique(results$outcome_variable)) > 1) {
  print(chisq.test(table(results$arm, results$outcome_variable), simulate.p.value = TRUE))
}
cat("\n")

cat("Chi-squared test: treatment_definition ~ arm\n")
if (length(unique(results$treatment_definition)) > 1) {
  print(chisq.test(table(results$arm, results$treatment_definition), simulate.p.value = TRUE))
}
cat("\n")

# ============================================================================
# 6. Plots
# ============================================================================

# ATT distribution by condition
p1 <- ggplot(results, aes(x = arm, y = att_estimate, fill = arm)) +
  geom_boxplot(alpha = 0.7) +
  geom_jitter(width = 0.2, alpha = 0.5, size = 2) +
  labs(
    x = "Treatment Condition",
    y = "Reported ATT Estimate",
    title = "Distribution of ATT Estimates by Treatment Condition"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

ggsave("output/att_by_arm.png", p1, width = 8, height = 6, dpi = 300)

# Permutation distribution for omnibus statistic
p2 <- ggplot(data.frame(statistic = perm_stats), aes(x = statistic)) +
  geom_histogram(bins = 50, fill = "gray70", color = "white") +
  geom_vline(xintercept = observed_stat, color = "#E63946", linewidth = 1.2) +
  labs(
    x = "Between-Condition Sum of Squares",
    y = "Count",
    title = "Omnibus Fisher Randomization Distribution",
    subtitle = sprintf("Observed statistic = %.4f, p = %.4f", observed_stat, omnibus_p)
  ) +
  theme_minimal()

ggsave("output/fisher_omnibus_permutation.png", p2, width = 8, height = 6, dpi = 300)

# Specification choices
p3 <- ggplot(results, aes(x = arm, fill = outcome_variable)) +
  geom_bar(position = "fill") +
  labs(
    x = "Treatment Condition",
    y = "Proportion",
    fill = "Outcome Variable",
    title = "Outcome Variable Choice by Condition"
  ) +
  theme_minimal()

ggsave("output/outcome_by_arm.png", p3, width = 10, height = 6, dpi = 300)

cat("\nPlots saved to output/\n")
cat("Done.\n")
