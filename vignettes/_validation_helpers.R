validation_method_labels <- c(
  inverse_penetration = "Inverse penetration",
  selection_rate2 = "Selection rate II"
)

validation_comparison_labels <- c(
  adjusted_vs_benchmark = "Adjusted vs benchmark",
  raw_vs_benchmark = "Raw vs benchmark",
  raw_vs_adjusted = "Raw vs adjusted"
)

validation_comparison_palette <- c(
  "Adjusted vs benchmark" = "#2B8CBE",
  "Raw vs benchmark" = "#756BB1",
  "Raw vs adjusted" = "#636363"
)

validation_reference_line_colour <- "#D95F0E"

validation_margin_level_labels <- c(
  origin_marginal = "Origin totals",
  destination_marginal = "Destination totals"
)

validation_margin_display_labels <- c(
  origin_marginal = "origin",
  destination_marginal = "destination"
)

validation_plot_method_labels <- c(
  "Inverse penetration" = "Inverse\npenetration",
  "Selection rate II" = "Selection\nrate II"
)

validation_flow_axis_label <- function(x) {
  dplyr::case_when(
    abs(x) >= 1e6 ~ paste0(round(x / 1e6, 1), "m"),
    abs(x) >= 1e3 ~ paste0(round(x / 1e3, 1), "k"),
    TRUE ~ format(round(x, 0), big.mark = ",", scientific = FALSE, trim = TRUE)
  )
}

validation_theme <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      legend.position = "bottom",
      panel.grid.minor = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold")
    )
}

validation_safe_cor <- function(x, y, method = "pearson") {
  keep <- is.finite(x) & is.finite(y)
  if (sum(keep) < 2L) {
    return(NA_real_)
  }

  x <- x[keep]
  y <- y[keep]
  if (stats::sd(x) <= 0 || stats::sd(y) <= 0) {
    return(NA_real_)
  }

  suppressWarnings(stats::cor(x, y, method = method))
}

validation_flow_metric_row <- function(data,
                                       level,
                                       method_name,
                                       comparison,
                                       estimate_col,
                                       reference_col) {
  x <- data[[estimate_col]]
  y <- data[[reference_col]]
  keep <- is.finite(x) & is.finite(y)
  x <- x[keep]
  y <- y[keep]

  if (length(x) == 0L) {
    return(tibble::tibble(
      level = level,
      method = method_name,
      method_label = validation_method_labels[[method_name]],
      comparison = comparison,
      comparison_label = validation_comparison_labels[[comparison]],
      n = 0L,
      mean_error = NA_real_,
      mae = NA_real_,
      rmse = NA_real_,
      median_absolute_error = NA_real_,
      mape = NA_real_,
      pearson_r = NA_real_,
      spearman_rho = NA_real_
    ))
  }

  error <- x - y
  denom <- ifelse(y == 0, NA_real_, y)
  mape <- 100 * mean(abs(error / denom), na.rm = TRUE)
  if (is.nan(mape)) {
    mape <- NA_real_
  }

  tibble::tibble(
    level = level,
    method = method_name,
    method_label = validation_method_labels[[method_name]],
    comparison = comparison,
    comparison_label = validation_comparison_labels[[comparison]],
    n = length(error),
    mean_error = mean(error, na.rm = TRUE),
    mae = mean(abs(error), na.rm = TRUE),
    rmse = sqrt(mean(error^2, na.rm = TRUE)),
    median_absolute_error = stats::median(abs(error), na.rm = TRUE),
    mape = mape,
    pearson_r = validation_safe_cor(x, y, method = "pearson"),
    spearman_rho = validation_safe_cor(x, y, method = "spearman")
  )
}

validation_comparison_metric_rows <- function(data, level, method_name) {
  dplyr::bind_rows(
    validation_flow_metric_row(
      data = data,
      level = level,
      method_name = method_name,
      comparison = "adjusted_vs_benchmark",
      estimate_col = "flow_adj",
      reference_col = "flow_bench"
    ),
    validation_flow_metric_row(
      data = data,
      level = level,
      method_name = method_name,
      comparison = "raw_vs_benchmark",
      estimate_col = "flow_mpd",
      reference_col = "flow_bench"
    ),
    validation_flow_metric_row(
      data = data,
      level = level,
      method_name = method_name,
      comparison = "raw_vs_adjusted",
      estimate_col = "flow_adj",
      reference_col = "flow_mpd"
    )
  )
}

validation_metrics_by_method <- function(data, level) {
  dplyr::bind_rows(
    lapply(
      split(data, data$method),
      function(x) {
        validation_comparison_metric_rows(
          data = x,
          level = level,
          method_name = unique(x$method)
        )
      }
    )
  )
}

validation_metrics_by_method_level <- function(data) {
  dplyr::bind_rows(
    lapply(
      split(data, interaction(data$method, data$level, drop = TRUE)),
      function(x) {
        validation_comparison_metric_rows(
          data = x,
          level = unique(x$level),
          method_name = unique(x$method)
        )
      }
    )
  )
}

validation_display_metrics <- function(metrics) {
  show_level <- length(unique(metrics$level)) > 1L
  show_marginal_level <- show_level &&
    all(metrics$level %in% names(validation_margin_display_labels))
  level_column <- if (show_marginal_level) {
    "Marginal total"
  } else {
    "Level"
  }

  display_metrics <- metrics |>
    dplyr::transmute(
      Level = dplyr::recode(
        level,
        !!!validation_margin_display_labels,
        .default = gsub("_", " ", level)
      ),
      Method = method_label,
      Comparison = comparison_label,
      n,
      `Pearson r` = round(pearson_r, 3),
      `Spearman rho` = round(spearman_rho, 3),
      `Mean error` = round(mean_error, 2),
      MAE = round(mae, 2),
      RMSE = round(rmse, 2),
      `Median absolute error` = round(median_absolute_error, 2),
      `MAPE (%)` = round(mape, 2)
    )

  if (!show_level) {
    display_metrics <- display_metrics |>
      dplyr::select(-Level)
  } else {
    names(display_metrics)[names(display_metrics) == "Level"] <- level_column
  }

  alignment <- ifelse(
    names(display_metrics) %in% c("Level", "Marginal total", "Method", "Comparison"),
    "l",
    "r"
  )

  knitr::kable(
    display_metrics,
    format = "html",
    row.names = FALSE,
    align = alignment,
    table.attr = 'class="table table-sm"'
  )
}

validation_display_residual_structure <- function(structure_results) {
  structure_summary <- dplyr::bind_rows(
    lapply(
      names(structure_results),
      function(method_name) {
        structure_results[[method_name]]$summary |>
          dplyr::mutate(
            method = method_name,
            method_label = dplyr::coalesce(
              unname(validation_method_labels[method_name]),
              method_name
            )
          )
      }
    )
  )

  structure_summary |>
    dplyr::transmute(
      Method = method_label,
      `Residual type` = residual_type,
      `Spatial role` = spatial_role,
      Aggregation = residual_aggregation,
      `OD pairs` = n_od_pairs,
      Areas = n_areas,
      `Residual vs benchmark-flow r` = round(pearson_residual_benchmark_flow, 3),
      `Moran's I` = round(moran_i, 3),
      `Residual vs covariate r` = round(pearson_residual_covariate, 3)
    ) |>
    knitr::kable(
      format = "html",
      row.names = FALSE,
      align = c("l", "l", "l", "l", rep("r", 5)),
      table.attr = 'class="table table-sm"'
    )
}

validation_display_residual_structure_areas <- function(structure_results,
                                                        area_names = NULL,
                                                        n = 5) {
  area_summary <- dplyr::bind_rows(
    lapply(
      names(structure_results),
      function(method_name) {
        structure_results[[method_name]]$area_level |>
          dplyr::mutate(
            method = method_name,
            method_label = dplyr::coalesce(
              unname(validation_method_labels[method_name]),
              method_name
            )
          )
      }
    )
  )

  if (!is.null(area_names)) {
    area_summary <- area_summary |>
      dplyr::left_join(area_names, by = "area")
  } else {
    area_summary <- area_summary |>
      dplyr::mutate(name = area)
  }

  area_summary |>
    dplyr::group_by(method_label) |>
    dplyr::slice_max(
      order_by = abs(selected_residual),
      n = n,
      with_ties = FALSE
    ) |>
    dplyr::ungroup() |>
    dplyr::arrange(method_label, dplyr::desc(abs(selected_residual))) |>
    dplyr::transmute(
      Method = method_label,
      Area = name,
      `Mean residual` = round(selected_residual, 2),
      `Mean absolute residual` = round(mean_abs_residual, 2),
      `Benchmark total` = round(benchmark_flow_sum, 0),
      `Raw MPD total` = round(mpd_flow_sum, 0),
      `Adjusted total` = round(adj_flow_sum, 0)
    ) |>
    knitr::kable(
      format = "html",
      row.names = FALSE,
      align = c("l", "l", rep("r", 5)),
      table.attr = 'class="table table-sm"'
    )
}

validation_build_flow_comparison <- function(method_results,
                                             mpd_df,
                                             benchmark_df) {
  dplyr::bind_rows(
    lapply(
      names(method_results),
      function(method_name) {
        method_results[[method_name]] |>
          dplyr::select(origin, destination, flow_adj) |>
          dplyr::inner_join(
            mpd_df |>
              dplyr::select(origin, destination, flow_mpd = flow),
            by = c("origin", "destination")
          ) |>
          dplyr::inner_join(
            benchmark_df |>
              dplyr::select(origin, destination, flow_bench = flow),
            by = c("origin", "destination")
          ) |>
          dplyr::mutate(
            method = method_name,
            method_label = validation_method_labels[[method_name]],
            .before = 1
          )
      }
    )
  )
}

validation_build_margins <- function(data) {
  dplyr::bind_rows(
    data |>
      dplyr::group_by(method, method_label, area = origin) |>
      dplyr::summarise(
        flow_mpd = sum(flow_mpd, na.rm = TRUE),
        flow_adj = sum(flow_adj, na.rm = TRUE),
        flow_bench = sum(flow_bench, na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::mutate(level = "origin_marginal", .after = method_label),
    data |>
      dplyr::group_by(method, method_label, area = destination) |>
      dplyr::summarise(
        flow_mpd = sum(flow_mpd, na.rm = TRUE),
        flow_adj = sum(flow_adj, na.rm = TRUE),
        flow_bench = sum(flow_bench, na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::mutate(level = "destination_marginal", .after = method_label)
  )
}

validation_build_ring_neighbors <- function(areas) {
  areas <- sort(unique(areas))
  if (length(areas) < 2L) {
    stop("At least two areas are required to build illustrative neighbours.")
  }

  dplyr::bind_rows(
    tibble::tibble(
      area = areas,
      neighbor = dplyr::lead(areas, default = areas[1])
    ),
    tibble::tibble(
      area = areas,
      neighbor = dplyr::lag(areas, default = areas[length(areas)])
    )
  ) |>
    dplyr::filter(area != neighbor)
}

validation_build_pair_scatter <- function(data) {
  if (!"level" %in% names(data)) {
    data <- data |>
      dplyr::mutate(level = "individual_flow")
  }

  dplyr::bind_rows(
    data |>
      dplyr::transmute(
        method,
        method_label,
        level,
        comparison = "Adjusted vs benchmark",
        comparison_axis_label = "adjusted (Y) vs\nbenchmark (X)",
        reference_flow = flow_bench,
        compared_flow = flow_adj,
        difference = flow_adj - flow_bench
      ),
    data |>
      dplyr::transmute(
        method,
        method_label,
        level,
        comparison = "Raw vs benchmark",
        comparison_axis_label = "raw (Y) vs\nbenchmark (X)",
        reference_flow = flow_bench,
        compared_flow = flow_mpd,
        difference = flow_mpd - flow_bench
      ),
    data |>
      dplyr::transmute(
        method,
        method_label,
        level,
        comparison = "Raw vs adjusted",
        comparison_axis_label = "raw (Y) vs\nadjusted (X)",
        reference_flow = flow_adj,
        compared_flow = flow_mpd,
        difference = flow_mpd - flow_adj
      )
  ) |>
    dplyr::mutate(
      comparison = factor(
        comparison,
        levels = c(
          "Adjusted vs benchmark",
          "Raw vs benchmark",
          "Raw vs adjusted"
        )
      ),
      comparison_axis_label = factor(
        comparison_axis_label,
        levels = c(
          "adjusted (Y) vs\nbenchmark (X)",
          "raw (Y) vs\nbenchmark (X)",
          "raw (Y) vs\nadjusted (X)"
        )
      )
    )
}

validation_pair_difference_limits <- function(data) {
  max_abs_difference <- data |>
    dplyr::pull(difference) |>
    abs() |>
    max(na.rm = TRUE)

  if (!is.finite(max_abs_difference) || max_abs_difference <= 0) {
    return(c(-1, 1))
  }

  c(-max_abs_difference, max_abs_difference)
}

validation_difference_colour_scale <- function(difference_limits) {
  ggplot2::scale_colour_gradient2(
    low = "#2166AC",
    mid = "#F7F7F7",
    high = "#B2182B",
    midpoint = 0,
    limits = difference_limits,
    labels = validation_flow_axis_label,
    name = "Difference\n(Y - X)"
  )
}

validation_plot_margin_scatter <- function(marginal_comparison, level = NULL) {
  margin_data <- marginal_comparison |>
    dplyr::filter(level %in% c("origin_marginal", "destination_marginal"))

  if (!is.null(level)) {
    margin_data <- margin_data |>
      dplyr::filter(level %in% !!level)
  }

  plot_data <- margin_data |>
    validation_build_pair_scatter() |>
    dplyr::mutate(
      level_label = dplyr::recode(
        level,
        !!!validation_margin_level_labels,
        .default = level
      ),
      method_plot_label = dplyr::recode(
        method_label,
        !!!validation_plot_method_labels,
        .default = method_label
      )
    )

  difference_limits <- validation_pair_difference_limits(plot_data)
  single_margin_level <- length(unique(plot_data$level_label)) == 1L
  margin_plot_title <- if (single_margin_level) {
    unique(plot_data$level_label)
  } else {
    NULL
  }
  margin_facet <- if (single_margin_level) {
    ggplot2::facet_grid(method_plot_label ~ comparison_axis_label, scales = "free")
  } else {
    ggplot2::facet_grid(
      level_label + method_plot_label ~ comparison_axis_label,
      scales = "free",
      labeller = ggplot2::label_value
    )
  }

  plot_data |>
    ggplot2::ggplot(
      ggplot2::aes(
        x = reference_flow,
        y = compared_flow,
        colour = difference
      )
    ) +
    ggplot2::geom_point(alpha = 0.75, size = 1.5, na.rm = TRUE) +
    ggplot2::geom_abline(
      intercept = 0,
      slope = 1,
      linetype = "dashed",
      colour = validation_reference_line_colour
    ) +
    margin_facet +
    validation_difference_colour_scale(difference_limits) +
    ggplot2::scale_x_continuous(labels = validation_flow_axis_label) +
    ggplot2::scale_y_continuous(labels = validation_flow_axis_label) +
    ggplot2::labs(
      title = margin_plot_title,
      x = "X-axis marginal total",
      y = "Y-axis marginal total"
    ) +
    validation_theme() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        face = "bold",
        hjust = 0.5,
        margin = ggplot2::margin(b = 6)
      )
    )
}

validation_plot_od_scatter <- function(flow_comparison) {
  plot_data <- flow_comparison |>
    validation_build_pair_scatter() |>
    dplyr::mutate(
      method_plot_label = dplyr::recode(
        method_label,
        !!!validation_plot_method_labels,
        .default = method_label
      )
    )

  difference_limits <- validation_pair_difference_limits(plot_data)

  plot_data |>
    ggplot2::ggplot(
      ggplot2::aes(
        x = reference_flow,
        y = compared_flow,
        colour = difference
      )
    ) +
    ggplot2::geom_point(alpha = 0.3, size = 0.9, na.rm = TRUE) +
    ggplot2::geom_abline(
      intercept = 0,
      slope = 1,
      linetype = "dashed",
      colour = validation_reference_line_colour
    ) +
    ggplot2::facet_grid(method_plot_label ~ comparison_axis_label, scales = "free") +
    validation_difference_colour_scale(difference_limits) +
    ggplot2::scale_x_continuous(labels = validation_flow_axis_label) +
    ggplot2::scale_y_continuous(labels = validation_flow_axis_label) +
    ggplot2::labs(
      x = "X-axis flow",
      y = "Y-axis flow"
    ) +
    validation_theme()
}

validation_plot_residual_outliers <- function(flow_comparison) {
  flow_comparison |>
    dplyr::mutate(adjusted_residual = flow_adj - flow_bench) |>
    ggplot2::ggplot(
      ggplot2::aes(
        x = flow_bench,
        y = flow_adj,
        colour = adjusted_residual
      )
    ) +
    ggplot2::geom_point(alpha = 0.75, size = 1.2, na.rm = TRUE) +
    ggplot2::geom_abline(
      intercept = 0,
      slope = 1,
      linetype = "dashed",
      colour = "grey40"
    ) +
    ggplot2::facet_wrap(~method_label, scales = "free") +
    ggplot2::scale_colour_gradient2(
      low = "#2166AC",
      mid = "#F7F7F7",
      high = "#B2182B",
      midpoint = 0,
      labels = validation_flow_axis_label,
      name = "Adjusted -\nbenchmark"
    ) +
    ggplot2::scale_x_continuous(labels = validation_flow_axis_label) +
    ggplot2::scale_y_continuous(labels = validation_flow_axis_label) +
    ggplot2::labs(
      x = "Benchmark flow",
      y = "Adjusted flow"
    ) +
    validation_theme()
}

validation_rank_largest_residuals <- function(flow_comparison, n = 10) {
  flow_comparison |>
    dplyr::mutate(
      raw_residual = flow_mpd - flow_bench,
      adjusted_residual = flow_adj - flow_bench,
      adjustment = flow_adj - flow_mpd,
      abs_error_reduction = abs(raw_residual) - abs(adjusted_residual),
      movement = dplyr::case_when(
        abs_error_reduction > 0 ~ "Closer to benchmark",
        abs_error_reduction < 0 ~ "Farther from benchmark",
        TRUE ~ "Unchanged"
      )
    ) |>
    dplyr::arrange(dplyr::desc(abs(adjusted_residual))) |>
    dplyr::select(
      method = method_label,
      origin,
      destination,
      flow_mpd,
      flow_adj,
      flow_bench,
      adjustment,
      adjusted_residual,
      abs_error_reduction,
      movement
    ) |>
    dplyr::slice_head(n = n)
}

validation_build_residual_heatmap <- function(flow_comparison) {
  raw_reference <- flow_comparison |>
    dplyr::select(origin, destination, flow_mpd, flow_bench) |>
    dplyr::distinct()

  adjusted_reference_sd <- flow_comparison |>
    dplyr::mutate(residual = flow_adj - flow_bench) |>
    dplyr::pull(residual) |>
    stats::sd(na.rm = TRUE)
  if (!is.finite(adjusted_reference_sd) || adjusted_reference_sd <= 0) {
    adjusted_reference_sd <- 1
  }

  residual_data <- dplyr::bind_rows(
    raw_reference |>
      dplyr::transmute(
        method_label = "Unadjusted",
        residual_source = "Raw MPD - benchmark",
        residual = flow_mpd - flow_bench
      ),
    flow_comparison |>
      dplyr::transmute(
        method_label,
        residual_source = "Adjusted - benchmark",
        residual = flow_adj - flow_bench
      )
  ) |>
    dplyr::mutate(
      residual_sd = adjusted_reference_sd,
      residual_sd_score = abs(residual) / residual_sd,
      residual_band = dplyr::case_when(
        residual_sd_score > 4 ~ "Greater than 4.0 SD",
        residual_sd_score > 3 ~ "3.0 to 4.0 SD",
        residual_sd_score > 2 ~ "2.0 to 3.0 SD",
        TRUE ~ "Less than 2.0 SD"
      )
    )

  method_levels <- c("Unadjusted", unname(validation_method_labels))
  band_levels <- c(
    "Less than 2.0 SD",
    "2.0 to 3.0 SD",
    "3.0 to 4.0 SD",
    "Greater than 4.0 SD"
  )

  heatmap_data <- residual_data |>
    dplyr::count(method_label, residual_band, name = "n") |>
    dplyr::group_by(method_label) |>
    dplyr::mutate(share = 100 * n / sum(n)) |>
    dplyr::ungroup()

  complete_grid <- expand.grid(
    method_label = method_levels,
    residual_band = band_levels,
    stringsAsFactors = FALSE
  )

  complete_grid |>
    dplyr::left_join(heatmap_data, by = c("method_label", "residual_band")) |>
    dplyr::mutate(
      n = dplyr::if_else(is.na(n), 0L, n),
      share = dplyr::if_else(is.na(share), 0, share),
      method_label = factor(method_label, levels = method_levels),
      method_axis = factor(
        dplyr::recode(
          as.character(method_label),
          "Unadjusted" = "Unadjusted\n(raw MPD)",
          "Inverse penetration" = "Inverse\npenetration",
          "Selection rate II" = "Selection rate\nII",
          .default = as.character(method_label)
        ),
        levels = c(
          "Unadjusted\n(raw MPD)",
          "Inverse\npenetration",
          "Selection rate\nII"
        )
      ),
      residual_band = factor(residual_band, levels = band_levels),
      label = sprintf("%.2f", share)
    )
}

validation_plot_residual_heatmap <- function(heatmap_data) {
  ggplot2::ggplot(
    heatmap_data,
    ggplot2::aes(x = method_axis, y = residual_band, fill = share)
  ) +
    ggplot2::geom_tile(width = 0.92, height = 0.92, colour = NA) +
    ggplot2::geom_text(ggplot2::aes(label = label), colour = "black", size = 3.7) +
    ggplot2::scale_fill_gradient(
      low = "#F7F7F7",
      high = "#08519C",
      name = "Share (%)"
    ) +
    ggplot2::scale_x_discrete(position = "bottom") +
    ggplot2::labs(
      x = NULL,
      y = "Origin-destination flows"
    ) +
    ggplot2::theme_minimal(base_size = 12.5) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      panel.border = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      axis.text.y = ggplot2::element_text(colour = "grey45"),
      axis.text.x = ggplot2::element_text(colour = "grey20"),
      axis.title.y = ggplot2::element_text(colour = "grey45"),
      axis.ticks = ggplot2::element_blank(),
      legend.position = "none"
    )
}
