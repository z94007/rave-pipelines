# Base-graphics visualizations for the stim-artifact-removal module.
# Each function is callable from the pipeline `main.Rmd` diagnostic chunks, the
# Shiny server (`renderPlot2`) and the report with identical arguments. No ggplot2.
# Reuses the axis/layout helpers in `shared-helpers.R`.


#' Qualitative palette for cluster colouring (colour-blind friendly-ish).
.stim_cluster_colors <- function(n) {
  base <- c("#1f77b4", "#d62728", "#2ca02c", "#9467bd", "#ff7f0e",
            "#17becf", "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22")
  if (n <= length(base)) { return(base[seq_len(n)]) }
  grDevices::hcl.colors(n, palette = "Dark 3")
}


#' (0) Raw stim-electrode trace with detected pulse onsets marked.
#'
#' @param trace numeric stim-channel trace
#' @param sample_rate sampling rate (Hz)
#' @param onsets integer sample indices of detected pulse onsets (1-based)
#' @param threshold optional amplitude threshold to draw as a horizontal line
#' @param time_range c(start, end) seconds to display (NA = full)
#' @param max_points display decimation cap
plot_stim_trace_with_onsets <- function(trace, sample_rate, onsets = NULL,
                                        threshold = NULL, time_range = c(NA, NA),
                                        cex = 1, max_points = 200000L,
                                        main = "Stim electrode with detected pulse onsets") {
  trace <- as.numeric(trace)
  n <- length(trace)
  tp <- (seq_len(n) - 1) / sample_rate

  t0 <- time_range[[1]]; t1 <- time_range[[2]]
  if (is.na(t0)) { t0 <- min(tp) }
  if (is.na(t1)) { t1 <- max(tp) }
  sel <- which(tp >= t0 & tp <= t1)
  if (!length(sel)) { sel <- seq_len(n) }

  draw <- sel
  if (length(draw) > max_points) {
    stride <- ceiling(length(draw) / max_points)
    draw <- draw[seq.int(1L, length(draw), by = stride)]
  }

  prepare_par(mfrow = c(1, 1), cex = cex)
  graphics::plot(
    tp[draw], trace[draw], type = "l", col = "black",
    xlab = "Time (s)", ylab = expression(mu * V), main = main
  )
  if (length(threshold) == 1 && is.finite(threshold)) {
    graphics::abline(h = threshold, col = "#2ca02c", lty = 2)
  }
  if (length(onsets)) {
    onsets <- as.integer(onsets)
    on_t <- (onsets - 1) / sample_rate
    on_t <- on_t[on_t >= t0 & on_t <= t1]
    graphics::abline(v = on_t, col = "#d6272855", lty = 1)
  }
}


#' (a) Overlaid stimulation-pulse snippets with the estimated template(s).
#'
#' @param snips (samples x pulses) matrix from `extract_snippets()`
#' @param sample_rate sampling rate (Hz)
#' @param pre samples before onset used when extracting (>= 0)
#' @param template_full optional template(s): a vector (single) or a
#'   (samples x n_clusters) matrix of per-cluster templates. Defaults to the
#'   per-sample mean across pulses.
#' @param cluster optional per-pulse cluster labels to colour the snippets
#' @param cex character expansion
plot_pulse_snippets_overlay <- function(snips, sample_rate, pre = 0,
                                        template_full = NULL, cluster = NULL,
                                        cex = 1, main = NULL) {
  snips <- as.matrix(snips)
  n_pulses <- ncol(snips)
  n_rows <- nrow(snips)
  snippet_time <- (seq_len(n_rows) - 1 - abs(pre)) / sample_rate * 1000

  if (is.null(template_full)) {
    template_full <- rowMeans(snips, na.rm = TRUE)
  }
  template_full <- as.matrix(template_full)

  # snippet colours (grey, or by cluster)
  if (length(cluster) == n_pulses) {
    cl <- as.integer(factor(cluster))
    cols_line <- paste0(.stim_cluster_colors(max(cl)), "40")[cl]
  } else {
    cols_line <- rep("gray80", n_pulses)
  }

  prepare_par(mfrow = c(1, 1), cex = cex)
  graphics::matplot(
    snippet_time, snips, type = "l", lty = 1, col = cols_line,
    xlab = "Time (ms)", ylab = expression(mu * V),
    main = if (is.null(main)) sprintf("Aligned pulses (n = %d)", n_pulses) else main
  )
  tcols <- .stim_cluster_colors(ncol(template_full))
  for (j in seq_len(ncol(template_full))) {
    graphics::lines(snippet_time, template_full[, j], col = tcols[[j]], lwd = 2)
  }
}


#' (b) Estimated stimulation template(s), with the blanked artifact region marked.
#'
#' @param template_full template(s): a vector or a (samples x n_clusters) matrix
#' @param sample_rate sampling rate (Hz)
#' @param blank_width number of leading (artifact) rows that were blanked
#' @param pre samples before onset used when extracting (>= 0)
plot_template_waveform <- function(template_full, sample_rate, blank_width = 0,
                                   pre = 0, cex = 1) {
  template_full <- as.matrix(template_full)
  n_rows <- nrow(template_full)
  k <- ncol(template_full)
  tt <- (seq_len(n_rows) - 1 - abs(pre)) / sample_rate * 1000
  cols <- .stim_cluster_colors(k)

  prepare_par(mfrow = c(1, 1), cex = cex)
  graphics::matplot(
    tt, template_full, type = "l", lty = 1, lwd = 2, col = cols,
    xlab = "Time (ms)", ylab = expression(mu * V),
    main = if (k > 1) sprintf("Estimated stim templates (%d clusters)", k)
           else "Estimated stimulation template"
  )
  blank_width <- as.integer(blank_width)
  if (isTRUE(blank_width > 0) && blank_width <= n_rows) {
    usr <- graphics::par("usr")
    graphics::rect(
      xleft = tt[[1]], ybottom = usr[[3]],
      xright = tt[[blank_width]], ytop = usr[[4]],
      col = "#ff000018", border = NA
    )
    graphics::mtext("blanked", side = 3, at = tt[[max(1L, blank_width %/% 2L)]],
                    line = -1, cex = 0.8 * cex, col = "#b2182b")
  }
  if (k > 1) {
    graphics::legend("topright", legend = colnames(template_full),
                     col = cols, lty = 1, lwd = 2, bty = "n", cex = cex)
  }
}


#' (c) Before/after comparison: raw vs cleaned trace on shared axes (MATLAB
#' "Original vs cleaned"). Restricts to `time_range` and decimates for display.
plot_before_after <- function(raw, cleaned, sample_rate, start_time = 0,
                              time_range = c(NA, NA), cex = 1,
                              max_points = 200000L, main = "Original vs cleaned") {
  raw <- as.numeric(raw)
  cleaned <- as.numeric(cleaned)
  n <- length(raw)
  tp <- (seq_len(n) - 1) / sample_rate + start_time

  t0 <- time_range[[1]]; t1 <- time_range[[2]]
  if (is.na(t0)) { t0 <- min(tp) }
  if (is.na(t1)) { t1 <- max(tp) }

  sel <- which(tp >= t0 & tp <= t1)
  if (!length(sel)) { sel <- seq_len(n) }

  if (length(sel) > max_points) {
    stride <- ceiling(length(sel) / max_points)
    sel <- sel[seq.int(1L, length(sel), by = stride)]
  }

  prepare_par(mfrow = c(1, 1), cex = cex)
  graphics::matplot(
    tp[sel], cbind(raw[sel], cleaned[sel]), type = "l", lty = 1,
    col = c("black", "red"),
    xlab = "Time (s)", ylab = expression(mu * V), main = main
  )
  graphics::legend(
    "topright", legend = c("Original", "Cleaned"),
    col = c("black", "red"), lty = 1, bty = "n", cex = cex
  )
}


#' (d) 2-D PCA score scatter of the pulses, optionally coloured by cluster.
#'
#' @param pca_scores list with `$scores` (pulses x PCs) and `$variance_explained`
#'   (e.g. the output of `snippet_pca()` or the `profile_pulses()` result)
#' @param cluster optional per-pulse cluster labels
plot_pca_scatter <- function(pca_scores, cluster = NULL, cex = 1) {
  if (!is.list(pca_scores) || is.null(pca_scores$scores)) {
    graphics::plot.new()
    graphics::text(0.5, 0.5, "PCA not available", cex = cex)
    return(invisible())
  }
  scores <- pca_scores$scores
  ve <- pca_scores$variance_explained
  if (ncol(scores) < 2) {
    scores <- cbind(scores, 0)
    ve <- c(ve, 0)
  }

  if (length(cluster) == nrow(scores)) {
    cl <- as.integer(factor(cluster))
    cols <- .stim_cluster_colors(max(cl))[cl]
  } else {
    cols <- "#00000080"
    cl <- NULL
  }

  prepare_par(mfrow = c(1, 1), cex = cex)
  graphics::plot(
    scores[, 1], scores[, 2], pch = 16, col = cols,
    xlab = sprintf("PC1 (%.1f%%)", 100 * ve[[1]]),
    ylab = sprintf("PC2 (%.1f%%)", 100 * ve[[2]]),
    main = "Pulse PCA scores"
  )
  graphics::abline(h = 0, v = 0, col = "#80808080", lty = 3)
  if (!is.null(cl)) {
    ucl <- sort(unique(cl))
    graphics::legend("topright", legend = paste("cluster", ucl),
                     col = .stim_cluster_colors(max(cl))[ucl], pch = 16,
                     bty = "n", cex = cex)
  }
}


#' (e) Welch periodogram comparison of two traces (e.g. monopolar vs bipolar, or
#' original vs cleaned), to show attenuation of stim-frequency harmonics.
#'
#' @param traces named list of numeric traces, OR a single numeric trace
#' @param sample_rate sampling rate (Hz)
#' @param win_sec Welch window length in seconds (window = floor(win_sec * fs))
#' @param max_freq upper frequency limit for the plot (Hz)
#' @param marks optional frequencies (e.g. stim harmonics) to mark with dashed lines
plot_pwelch_compare <- function(traces, sample_rate, win_sec = 1,
                                max_freq = 500, marks = NULL, cex = 1,
                                main = "Welch periodogram") {
  if (!is.list(traces)) { traces <- list(signal = traces) }
  nm <- names(traces)
  if (is.null(nm)) { nm <- paste0("trace", seq_along(traces)) }

  win <- max(16L, floor(win_sec * sample_rate))
  cols <- c("black", "red", "#1f77b4", "#2ca02c")[seq_along(traces)]

  pws <- lapply(traces, function(x) {
    x <- as.numeric(x)
    x <- x[is.finite(x)]
    ravetools::pwelch(x, fs = sample_rate, window = win,
                      noverlap = win %/% 2L, plot = 0)
  })

  prepare_par(mfrow = c(1, 1), cex = cex)
  freq <- pws[[1]]$freq
  fsel <- freq > 0 & freq <= max_freq
  yr <- range(unlist(lapply(pws, function(p) p$spec_db[fsel])), na.rm = TRUE)

  graphics::plot(
    freq[fsel], pws[[1]]$spec_db[fsel], type = "l", col = cols[[1]], ylim = yr,
    xlab = "Frequency (Hz)", ylab = "Power (dB)", main = main
  )
  if (length(pws) > 1) {
    for (j in 2:length(pws)) {
      graphics::lines(freq[fsel], pws[[j]]$spec_db[fsel], col = cols[[j]])
    }
  }
  if (length(marks)) {
    graphics::abline(v = marks[marks <= max_freq], col = "#80808066", lty = 3)
  }
  graphics::legend("topright", legend = nm, col = cols, lty = 1, bty = "n", cex = cex)
}
