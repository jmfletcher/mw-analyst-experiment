#!/usr/bin/env Rscript
# Substack-style strip plots and negative-arm comparison table.
#
# Usage:
#   Rscript scripts/plot_substack_style.R
#   Rscript scripts/plot_substack_style.R "Second Step/results" "reports/figures"

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(tidyr)
})

args <- commandArgs(trailingOnly = TRUE)
results_dir <- if (length(args) >= 1) args[[1]] else "Second Step/results"
fig_dir <- if (length(args) >= 2) args[[2]] else "reports/figures"
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

results <- read.csv(file.path(results_dir, "results_all.csv"), stringsAsFactors = FALSE) |>
  mutate(
    arm = sub("_[0-9]+$", "", agent_id),
    years_start = as.integer(years_start),
    years_end = as.integer(years_end),
    year_span = years_end - years_start + 1,
    est_lc = tolower(trimws(estimator)),
    twfe = grepl("twfe|feols|fixest", est_lc),
    continuous_tx = grepl("continuous", tolower(treatment_definition)),
    att_pvalue = suppressWarnings(as.numeric(att_pvalue)),
    sig_neg = att_pvalue < 0.05 & att_estimate < 0,
    three_arm = case_when(
      arm == "none" ~ "Control (No Context)",
      arm %in% c("null_short", "null_cites") ~ "Null Context",
      arm %in% c("negative_short", "negative_cites") ~ "Negative Context",
      TRUE ~ NA_character_
    )
  )

between_arm_ss <- function(values, arms) {
  arms <- droplevels(as.factor(arms))
  overall_mean <- mean(values, na.rm = TRUE)
  arm_means <- tapply(values, arms, mean, na.rm = TRUE)
  arm_counts <- table(arms)
  sum(arm_counts[names(arm_means)] * (arm_means - overall_mean)^2)
}

fisher_p_three_arm <- function(df) {
  set.seed(42)
  obs <- between_arm_ss(df$att_estimate, df$three_arm)
  mean(replicate(10000, between_arm_ss(df$att_estimate, sample(df$three_arm))) >= obs)
}

substack_colors <- c(
  "Control (No Context)" = "#8A8A8A",
  "Null Context" = "#4F81BD",
  "Negative Context" = "#C0504D"
)

plot_substack_strip <- function(df, title, subtitle, x_limits = NULL) {
  df <- df |>
    mutate(three_arm = factor(three_arm, levels = names(substack_colors)))

  arm_means <- df |>
    group_by(three_arm) |>
    summarize(mean_att = mean(att_estimate), .groups = "drop")

  p <- ggplot(df, aes(x = att_estimate, y = three_arm, color = three_arm)) +
    geom_vline(xintercept = 0, linewidth = 0.35, color = "black") +
    geom_point(
      alpha = 0.55,
      size = 2.4,
      position = position_jitter(height = 0.14, seed = 42)
    ) +
    geom_point(
      data = arm_means,
      aes(x = mean_att, y = three_arm),
      inherit.aes = FALSE,
      shape = 18,
      size = 3.8,
      color = "black"
    ) +
    scale_color_manual(values = substack_colors) +
    labs(title = title, subtitle = subtitle, x = "ATT Estimate", y = NULL) +
    theme_minimal(base_size = 11) +
    theme(
      legend.position = "none",
      panel.grid.major.y = element_line(color = "grey88", linewidth = 0.3),
      panel.grid.major.x = element_line(color = "grey88", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      plot.title = element_text(face = "bold", size = 12, hjust = 0),
      plot.subtitle = element_text(color = "grey35", size = 9, hjust = 0),
      axis.text.y = element_text(size = 10)
    )

  if (!is.null(x_limits)) {
    p <- p + coord_cartesian(xlim = x_limits)
  }
  p
}

# Exclude extreme outlier (Substack Wave 1 excluded ATT = -0.908)
outlier_threshold <- -0.08
df_main <- results |> filter(is.na(att_estimate) | att_estimate > outlier_threshold)
n_excluded <- sum(results$att_estimate <= outlier_threshold, na.rm = TRUE)
outlier_note <- if (n_excluded > 0) {
  sprintf("Outlier(s) with ATT <= %.3f excluded.", outlier_threshold)
} else {
  "No extreme outliers excluded."
}

fisher_main <- fisher_p_three_arm(df_main)

p_wave1_style <- plot_substack_strip(
  df_main,
  title = sprintf("%d Cursor agents, same data, same question — different answers", nrow(df_main)),
  subtitle = sprintf(
    "Each dot is one agent's ATT. Diamonds = arm means. %s Fisher p = %.4f (three arms).",
    outlier_note, fisher_main
  ),
  x_limits = c(-0.025, 0.015)
)

ggsave(
  file.path(fig_dir, "substack_wave1_style_strip.png"),
  p_wave1_style, width = 8, height = 4.2, dpi = 300, bg = "white"
)

p_wave2_style <- plot_substack_strip(
  df_main,
  title = "Cursor run (TWFE allowed): Negative-context agents do not shift left",
  subtitle = sprintf(
    "Mapped to Cunningham's three arms (control / null / negative). Fisher p = %.4f. Diamonds = arm means.",
    fisher_main
  ),
  x_limits = c(-0.06, 0.02)
)

ggsave(
  file.path(fig_dir, "substack_wave2_style_strip.png"),
  p_wave2_style, width = 8, height = 4.2, dpi = 300, bg = "white"
)

summarize_negative_group <- function(df, label) {
  tibble(
    group = label,
    n = nrow(df),
    mean_estimate = mean(df$att_estimate),
    q25 = quantile(df$att_estimate, 0.25),
    q75 = quantile(df$att_estimate, 0.75),
    median = median(df$att_estimate),
    sd = sd(df$att_estimate),
    pct_sig = 100 * mean(df$sig_neg, na.rm = TRUE),
    n_sig = sum(df$sig_neg, na.rm = TRUE),
    mean_panel_yrs = mean(df$year_span, na.rm = TRUE),
    pct_binary = 100 * mean(!df$continuous_tx, na.rm = TRUE),
    pct_continuous = 100 * mean(df$continuous_tx, na.rm = TRUE)
  )
}

neg <- results |> filter(grepl("^negative", arm))
neg_cs <- neg |> filter(!twfe)
neg_twfe <- neg |> filter(twfe)

cursor_table <- bind_rows(
  summarize_negative_group(neg_cs, "Cursor: negative-CS"),
  summarize_negative_group(neg_twfe, "Cursor: negative-TWFE")
)

cunningham_table <- tribble(
  ~group, ~n, ~mean_estimate, ~q25, ~q75, ~median, ~sd,
  ~pct_sig, ~n_sig, ~mean_panel_yrs, ~pct_binary, ~pct_continuous,
  "Cunningham Wave 1: negative-CS", 49, -0.004, -0.012, 0.002, -0.009, 0.010,
  6, 3, 17.1, 100, 0,
  "Cunningham Wave 2: negative-TWFE", 13, -0.024, -0.026, -0.007, -0.019, 0.018,
  46, 6, 21.6, 31, 69
)

comparison_table <- bind_rows(cunningham_table, cursor_table)
write.csv(comparison_table, file.path(fig_dir, "substack_negative_cs_vs_twfe_table.csv"), row.names = FALSE)

cat("Wrote figures to", fig_dir, "\n")
cat("Fisher p (three arms):", fisher_main, "\n")
print(comparison_table)
