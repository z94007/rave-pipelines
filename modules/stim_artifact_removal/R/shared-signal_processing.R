# Signal-processing helpers for stimulation-artifact removal.
#
# Faithful R port of the MATLAB prototype (tmp/artifact_rej.m). Pulse detection is
# either from a trigger/sync channel (threshold -> connected-component trains ->
# `linspace` per-pulse locations, MATLAB L49-71) or from a preloaded stim epoch;
# alignment is the MATLAB local min/max method (L82-95). No `ravetools` detection
# or alignment is used.


# ---- One-repository channel extraction ---------------------------------------

#' Extract the traces for a set of electrodes from a single block's container,
#' searching across signal-type groups (recording and trigger channels may be
#' different signal types but come from the same repository). Columns of `$data`
#' are ordered to match `electrodes`.
extract_block_signal <- function(block_container, electrodes) {
  electrodes <- as.integer(electrodes)
  cols <- vector("list", length(electrodes))
  sample_rate <- NULL
  time <- NULL

  for (stype in names(block_container)) {
    si <- block_container[[stype]]
    el <- as.integer(si$dimnames$Electrode)
    sel <- el %in% electrodes
    if (!any(sel)) { next }

    dat <- si$data[, sel, drop = FALSE, dimnames = FALSE]
    el_sel <- el[sel]
    for (j in which(electrodes %in% el_sel)) {
      cols[[j]] <- dat[, which(el_sel == electrodes[[j]])[[1]]]
    }
    if (is.null(sample_rate)) {
      sample_rate <- si$sample_rate
      time <- si$dimnames$Time
    }
  }

  if (any(vapply(cols, is.null, logical(1)))) {
    stop("Some requested electrodes were not found in this recording block: ",
         paste(electrodes, collapse = ", "))
  }

  list(data = do.call(cbind, cols), sample_rate = sample_rate, time = time)
}


# ---- Gap filling (MATLAB `fillmissing`) --------------------------------------

#' Fill NaN entries with a centered moving mean (MATLAB `fillmissing(x,'movmean',k)`).
#' O(n) via cumsum; the window shrinks at the edges (MATLAB default).
fill_missing_movmean <- function(x, window = 101L) {
  x <- as.numeric(x)
  n <- length(x)
  if (!n || !anyNA(x)) { return(x) }

  window <- max(1L, as.integer(window))
  half <- window %/% 2L

  na <- is.na(x)
  xv <- x
  xv[na] <- 0
  isval <- as.numeric(!na)

  cs_val <- c(0, cumsum(xv))
  cs_cnt <- c(0, cumsum(isval))

  idx <- which(na)
  lo <- pmax(1L, idx - half)
  hi <- pmin(n, idx + half)

  s   <- cs_val[hi + 1L] - cs_val[lo]
  cnt <- cs_cnt[hi + 1L] - cs_cnt[lo]

  filled <- x
  ok <- cnt > 0
  filled[idx[ok]] <- s[ok] / cnt[ok]
  filled
}

#' Fill remaining NaN with the nearest (by index) non-NaN value
#' (MATLAB `fillmissing(x,'nearest')`). Ties resolve to the left neighbour.
fill_missing_nearest <- function(x) {
  x <- as.numeric(x)
  if (!anyNA(x)) { return(x) }
  ok <- which(!is.na(x))
  if (!length(ok)) { return(x) }

  pos <- seq_along(x)
  li <- findInterval(pos, ok)              # # of known indices <= pos (0 if none to left)

  left_k  <- ifelse(li >= 1L, li, NA_integer_)
  right_k <- ifelse(li + 1L <= length(ok), li + 1L, NA_integer_)
  left_idx  <- ifelse(is.na(left_k),  NA_integer_, ok[pmax(left_k, 1L)])
  right_idx <- ifelse(is.na(right_k), NA_integer_, ok[pmin(right_k, length(ok))])

  dl <- abs(pos - left_idx)
  dr <- abs(pos - right_idx)
  nearest_idx <- ifelse(
    is.na(left_idx), right_idx,
    ifelse(is.na(right_idx), left_idx,
           ifelse(dl <= dr, left_idx, right_idx)))

  out <- x
  na <- is.na(x)
  out[na] <- x[nearest_idx[na]]
  out
}


# ---- Detection: trigger/sync channel (faithful MATLAB, L49-71) ---------------

#' Detect pulse locations from a trigger/sync channel.
#' Threshold -> connected-component trains -> `linspace` per-pulse locations.
#' Returns a `pulse_info` list (`n_pulses`, `onset_index`, `offset_index`, 1-based).
detect_pulses_from_trigger <- function(trigger, sample_rate, threshold,
                                       stim_frequency, stim_length,
                                       pulse_duration_sec) {
  trigger <- as.numeric(trigger)
  n <- length(trigger)

  snip_win <- round(sample_rate / stim_frequency)          # MATLAB snipWin
  n_per_train <- max(1L, round(stim_frequency * stim_length))  # MATLAB nPerPulse

  bin <- trigger > threshold
  d <- diff(c(0L, as.integer(bin), 0L))
  onset <- which(d == 1L)
  offset <- which(d == -1L) - 1L

  n_trains <- min(length(onset), length(offset))
  if (!n_trains) {
    return(list(n_pulses = 0L, onset_index = integer(0), offset_index = integer(0)))
  }
  onset <- onset[seq_len(n_trains)]
  offset <- offset[seq_len(n_trains)]

  loc <- unlist(lapply(seq_len(n_trains), function(k) {
    last <- offset[[k]] - snip_win
    if (last <= onset[[k]]) { return(integer(0)) }
    round(seq(onset[[k]], last, length.out = n_per_train))   # MATLAB linspace
  }))

  loc <- as.integer(loc)
  loc <- loc[loc > 0 & (loc + snip_win) <= n]                # MATLAB bounds check

  list(
    n_pulses = length(loc),
    onset_index = loc,
    offset_index = loc + round(pulse_duration_sec * sample_rate)
  )
}


# ---- Detection: stim electrode (per-pulse, abs-threshold + refractory) --------

#' Detect individual pulse onsets by thresholding the STIM ELECTRODE itself.
#'
#' Unlike a dedicated sync/"Events" channel (which stays high for a whole train),
#' the stim electrode fires one saturating square pulse at a time and rails in
#' BOTH directions, so a single pulse crosses the threshold several times. We
#' therefore threshold the ABSOLUTE value and coalesce crossings with a refractory
#' period: an onset is kept only if it is at least `refractory_frac` of one
#' inter-pulse interval (`sample_rate / stim_frequency`) after the previous kept
#' onset. This yields one reliable timestamp per pulse. Returns the standard
#' `pulse_info` list (`n_pulses`, `onset_index`, `offset_index`, 1-based).
detect_pulses_from_stim_channel <- function(signal, sample_rate, threshold,
                                            stim_frequency, refractory_frac = 0.8,
                                            pulse_duration_sec = 0) {
  signal <- as.numeric(signal)
  n <- length(signal)
  inter_pulse <- max(1L, round(sample_rate / stim_frequency))
  min_dist <- max(1L, round(refractory_frac * inter_pulse))

  bin <- abs(signal) > threshold                     # rails in both directions
  d <- diff(c(0L, as.integer(bin), 0L))
  on <- which(d == 1L)
  if (!length(on)) {
    return(list(n_pulses = 0L, onset_index = integer(0), offset_index = integer(0)))
  }

  # refractory: keep an onset only if >= min_dist from the last kept one
  keep <- integer(length(on))
  m <- 0L
  last <- -Inf
  for (o in on) {
    if (o - last >= min_dist) { m <- m + 1L; keep[[m]] <- o; last <- o }
  }
  loc <- keep[seq_len(m)]

  # need a full inter-pulse window after each onset
  loc <- loc[loc > 0 & (loc + inter_pulse) <= n]

  list(
    n_pulses = length(loc),
    onset_index = loc,
    offset_index = loc + round(pulse_duration_sec * sample_rate)
  )
}


# ---- Detection: preloaded stim epoch (RAVE-native alternative) ----------------

#' Derive pulse locations for a block from a stim epoch table.
#' `onset = round(Time * fs) + 1`; `offset = round(Event_StimOffset * fs) + 1`
#' when present, else `onset + round(pulse_duration * fs)`.
detect_pulses_from_epoch <- function(epoch_table, block, sample_rate,
                                     pulse_duration_sec) {
  empty <- list(n_pulses = 0L, onset_index = integer(0), offset_index = integer(0))
  if (!is.data.frame(epoch_table) || !nrow(epoch_table)) { return(empty) }

  bt <- epoch_table[as.character(epoch_table$Block) == as.character(block), , drop = FALSE]
  if (!nrow(bt)) { return(empty) }

  onset <- as.integer(round(bt$Time * sample_rate)) + 1L
  ord <- order(onset)
  onset <- onset[ord]

  if ("Event_StimOffset" %in% names(bt) && all(is.finite(bt$Event_StimOffset[ord]))) {
    offset <- as.integer(round(bt$Event_StimOffset[ord] * sample_rate)) + 1L
  } else {
    offset <- onset + round(pulse_duration_sec * sample_rate)
  }

  list(n_pulses = length(onset), onset_index = onset, offset_index = offset)
}


# ---- Detection: Events / sync channel (preferred, MATLAB-faithful) -----------

#' Robust threshold for a bimodal (square-wave) channel: the midpoint between the
#' low and high modes, estimated from the 2nd/98th percentiles to ignore spikes.
bimodal_threshold <- function(x) {
  x <- as.numeric(x)
  x <- x[is.finite(x)]
  if (!length(x)) { return(0) }
  q <- stats::quantile(x, c(0.02, 0.98), names = FALSE)
  as.numeric(q[[1]] + 0.5 * (q[[2]] - q[[1]]))
}

#' Auto-detect the Events / sync channel among the subject's Auxiliary channels
#' by SHAPE: the clean square wave has almost no samples at intermediate levels
#' (high "squareness") and a plausible number of train edges. RAVE does not
#' preserve the original "Events" channel name (labels become `NoLabel`), so we
#' identify it from the waveform. Returns the electrode number, or `NULL`.
auto_detect_event_channel <- function(subject, block, aux_electrodes = NULL) {
  if (is.null(aux_electrodes)) {
    aux_electrodes <- subject$electrodes[subject$electrode_types == "Auxiliary"]
  }
  aux_electrodes <- as.integer(aux_electrodes)
  if (!length(aux_electrodes)) { return(NULL) }

  repo <- ravecore::prepare_subject_raw_voltage_with_blocks(
    subject = subject, electrodes = aux_electrodes,
    blocks = block, downsample = NA)
  container <- repo$get_container()[[as.character(block)]]

  best <- NULL
  best_score <- -Inf
  for (ch in aux_electrodes) {
    ex <- extract_block_signal(container, ch)
    x <- as.numeric(ex$data[, 1])
    n <- length(x)
    sr <- ex$sample_rate
    rng <- range(x, na.rm = TRUE)
    span <- diff(rng)
    if (!isTRUE(span > 0)) { next }

    lo <- rng[[1]] + 0.1 * span
    hi <- rng[[2]] - 0.1 * span
    mid_mass <- mean(x >= lo & x <= hi, na.rm = TRUE)      # low => square
    squareness <- 1 - mid_mass

    thr <- bimodal_threshold(x)
    n_rise <- sum(diff(c(0L, as.integer(x > thr), 0L)) == 1L)
    duration_sec <- n / sr
    if (n_rise < 2L || n_rise > duration_sec * 10) { next } # implausible train count

    if (squareness > best_score) { best_score <- squareness; best <- ch }
  }
  best
}

#' Detect pulse onsets from the Events / sync channel. The channel is high for
#' the whole train; `detect_pulses_from_trigger` finds each train as a connected
#' component and lays `stim_frequency * stim_train_duration` evenly spaced onsets
#' inside it (MATLAB `linspace`). The threshold is auto-estimated (bimodal) unless
#' supplied.
detect_pulses_from_events <- function(events_signal, sample_rate, stim_frequency,
                                      stim_train_duration, pulse_duration_sec = 0,
                                      threshold = NULL) {
  events_signal <- as.numeric(events_signal)
  if (is.null(threshold)) { threshold <- bimodal_threshold(events_signal) }
  detect_pulses_from_trigger(
    trigger = events_signal, sample_rate = sample_rate, threshold = threshold,
    stim_frequency = stim_frequency, stim_length = stim_train_duration,
    pulse_duration_sec = pulse_duration_sec)
}


# ---- Snippet extraction (MATLAB `snips(:,i)=bipolar(loc:loc+snipWin)`) --------

#' Extract per-pulse snippets into a (samples x pulses) matrix.
#' Row `r` corresponds to signal sample `onset_index[i] + (r - 1 - pre)`.
#' Out-of-bounds samples (near block edges) become `NA`.
extract_snippets <- function(signal, onset_index, snip_window, pre = 0L) {
  signal <- as.numeric(signal)
  n <- length(signal)

  pre <- abs(as.integer(pre))
  win <- as.integer(snip_window)
  row_offsets <- seq.int(-pre, win)
  n_rows <- length(row_offsets)

  onset_index <- as.integer(onset_index)
  n_pulses <- length(onset_index)

  snips <- matrix(NA_real_, nrow = n_rows, ncol = n_pulses)
  for (i in seq_len(n_pulses)) {
    idx <- onset_index[[i]] + row_offsets
    keep <- idx >= 1L & idx <= n
    snips[keep, i] <- signal[idx[keep]]
  }
  snips
}


# ---- Alignment: local min/max (faithful MATLAB, L82-95) ----------------------

#' Align pulses by the local extremum within rows `search_start:search_end`.
#' Faithful to MATLAB: pick min or max polarity by which has the larger mean
#' magnitude, then shift each onset by `ix - ix[1]`. Returns a bounds-filtered
#' `pulse_info` list.
align_pulses_minmax <- function(signal, onset_index, snip_window,
                                search_start = 15L, search_end = 20L,
                                pulse_duration_samples = 0L) {
  signal <- as.numeric(signal)
  n <- length(signal)
  onset_index <- as.integer(onset_index)
  win <- as.integer(snip_window)

  snips <- extract_snippets(signal, onset_index, snip_window = win, pre = 0L)
  n_rows <- nrow(snips)

  s0 <- max(1L, as.integer(search_start))
  s1 <- min(n_rows, as.integer(search_end))
  if (s1 <= s0 || ncol(snips) < 1L) {
    # search window invalid -> no alignment
    return(list(n_pulses = length(onset_index), onset_index = onset_index,
                offset_index = onset_index + pulse_duration_samples))
  }

  sub <- snips[s0:s1, , drop = FALSE]
  ix_min <- apply(sub, 2, which.min)
  ix_max <- apply(sub, 2, which.max)
  min_val <- apply(sub, 2, min, na.rm = TRUE)
  max_val <- apply(sub, 2, max, na.rm = TRUE)

  ix <- if (abs(mean(min_val)) >= abs(mean(max_val))) ix_min else ix_max
  shift <- ix - ix[[1]]
  loc_aligned <- onset_index + shift                      # MATLAB loc + (ix - ix(1))

  keep <- loc_aligned > 0 & (loc_aligned + win) <= n      # MATLAB bounds check
  loc_aligned <- loc_aligned[keep]

  list(
    n_pulses = length(loc_aligned),
    onset_index = loc_aligned,
    offset_index = loc_aligned + pulse_duration_samples
  )
}


# ---- Template estimation (MATLAB `temp1 = detrend(mean(X,1),0)`) --------------

#' Estimate the artifact template from aligned snippets. The first `blank_width`
#' rows (direct artifact) AND the last row (MATLAB `psnips(601,:)`, the sample
#' shared with the next pulse) are blanked; the template is the demeaned average
#' of the remaining rows across pulses.
compute_stim_template <- function(snips, blank_width = 20L) {
  snips <- as.matrix(snips)
  n_rows <- nrow(snips)

  blank_width <- max(0L, min(as.integer(blank_width), n_rows))
  blank_rows <- unique(c(seq_len(blank_width), n_rows))    # first blank_width + last row
  blank_rows <- blank_rows[blank_rows >= 1L & blank_rows <= n_rows]
  valid_rows <- setdiff(seq_len(n_rows), blank_rows)

  mean_valid <- rowMeans(snips[valid_rows, , drop = FALSE], na.rm = TRUE)
  # `detrend(..., 0)` == remove the mean (constant detrend)
  template_valid <- mean_valid - mean(mean_valid, na.rm = TRUE)
  template_valid[!is.finite(template_valid)] <- 0

  template_full <- rep(NA_real_, n_rows)
  template_full[valid_rows] <- template_valid

  list(
    template_valid = template_valid,
    valid_rows = valid_rows,
    blank_rows = blank_rows,
    template_full = template_full
  )
}


# ---- PCA of the pulses (MATLAB `pca(X)`, inspection only) --------------------

#' PCA of the per-pulse snippets (pulses as observations). Inspection only:
#' produces the 2-D score scatter; does not feed the cleaning path.
snippet_pca <- function(snips, valid_rows = NULL, n_components = 2L) {
  snips <- as.matrix(snips)
  if (is.null(valid_rows)) { valid_rows <- seq_len(nrow(snips)) }

  X <- t(snips[valid_rows, , drop = FALSE])   # pulses x samples
  ok <- stats::complete.cases(X)
  n_components <- max(1L, as.integer(n_components))

  if (sum(ok) <= n_components || ncol(X) < 2L) { return(NULL) }

  k <- min(n_components, ncol(X), sum(ok) - 1L)
  pr <- stats::prcomp(X[ok, , drop = FALSE], center = TRUE, scale. = FALSE, rank. = k)

  scores <- pr$x[, seq_len(k), drop = FALSE]
  colnames(scores) <- paste0("PC", seq_len(k))

  list(
    scores = scores,
    sdev = pr$sdev,
    variance_explained = (pr$sdev^2) / sum(pr$sdev^2),
    observations = which(ok)
  )
}


# ---- Template subtraction + write-back + gap fill (MATLAB L135-199) -----------

#' Subtract the template from every pulse, blank the direct-artifact region,
#' write the corrected snippets back into a copy of the full trace with bounds
#' checks, then fill the blanked gaps by moving average + nearest.
subtract_template_and_fill <- function(signal, snips, onset_index, pre,
                                       template, gap_fill_window = 101L) {
  signal <- as.numeric(signal)
  n <- length(signal)
  cleaned <- signal

  snips <- as.matrix(snips)
  n_rows <- nrow(snips)
  pre <- abs(as.integer(pre))

  template_valid <- template$template_valid
  valid_rows <- template$valid_rows
  blank_rows <- template$blank_rows

  onset_index <- as.integer(onset_index)
  for (i in seq_along(onset_index)) {
    vals <- snips[, i]
    vals[valid_rows] <- vals[valid_rows] - template_valid   # template subtraction
    vals[blank_rows] <- NA_real_                            # direct-artifact -> NaN

    idx <- onset_index[[i]] + (seq_len(n_rows) - 1L - pre)
    keep <- idx >= 1L & idx <= n
    cleaned[idx[keep]] <- vals[keep]
  }

  cleaned <- fill_missing_movmean(cleaned, window = gap_fill_window)
  cleaned <- fill_missing_nearest(cleaned)
  cleaned
}


# ---- filearray-backed storage ------------------------------------------------

#' Create a `filearray` at `filebase` from a matrix and wrap it as a
#' `RAVEFileArray` (a light, disk-backed handle that serializes by reference).
#' Overwrites any existing array at that path.
new_rave_filearray <- function(filebase, data, dimnames_list = NULL, headers = list()) {
  data <- as.matrix(data)
  if (file.exists(filebase)) { unlink(filebase, recursive = TRUE) }
  ravepipeline::dir_create2(dirname(filebase))

  farr <- filearray::filearray_create(
    filebase = filebase, dimension = dim(data),
    type = "float", partition_size = 1L, initialize = FALSE
  )
  farr[] <- data
  if (!is.null(dimnames_list)) { dimnames(farr) <- dimnames_list }
  for (nm in names(headers)) {
    farr$set_header(nm, headers[[nm]], save = FALSE)
  }
  ravepipeline::RAVEFileArray$new(x = farr, temporary = FALSE)
}


# ---- Stim-channel accessor ---------------------------------------------------

#' Read the stim electrode's raw trace for one or more blocks.
#' If `stim_electrode` is already loaded in `repository`, read it from the
#' container; otherwise build a repository with the SAME subject / downsample but
#' that electrode and read from it (loading the stim channel can happen after the
#' main repository was prepared). Returns, per block, a list(data, sample_rate,
#' time); if a single `block` is requested, returns that one list directly.
load_stim_channel <- function(repository, stim_electrode, block = NULL) {
  stim_electrode <- as.integer(stim_electrode)[[1]]

  in_repo <- stim_electrode %in% as.integer(repository$electrode_list)
  rep_use <- if (in_repo) {
    repository
  } else {
    ravecore::prepare_subject_raw_voltage_with_blocks(
      subject = repository$subject,
      electrodes = stim_electrode,
      blocks = repository$blocks,
      downsample = NA
    )
  }

  container <- rep_use$get_container()
  blocks <- if (is.null(block)) rep_use$blocks else as.character(block)

  out <- lapply(blocks, function(b) {
    ex <- extract_block_signal(container[[b]], stim_electrode)
    list(data = as.numeric(ex$data[, 1]), sample_rate = ex$sample_rate, time = ex$time)
  })
  names(out) <- blocks

  if (!is.null(block) && length(block) == 1L) { return(out[[as.character(block)]]) }
  out
}


# ---- Stim-aware within-shaft bipolar pairing ---------------------------------

#' Build bipolar re-reference pairs that stay WITHIN a shaft and SKIP (bridge
#' across) the stim electrode(s). The shaft is the electrode label with trailing
#' digits stripped (`LabelPrefix` when present, else `gsub("[0-9]+$","",Label)`,
#' matching `reference_module`). Within each shaft, contacts that are loaded and
#' not a stim electrode are ordered by number and paired adjacently; removing the
#' stim contact makes its two neighbours adjacent (e.g. stim 38 -> pair 37-39).
#' Only pairs with at least one contact in `analysis_electrodes` are returned.
#'
#' @return data.frame(anode, cathode, label "a-b", shaft, bridged) where
#'   `bridged` marks pairs whose contacts are not consecutively numbered (a
#'   stim contact was skipped between them).
build_bipolar_pairs <- function(electrode_table, analysis_electrodes,
                                stim_electrodes = integer(0),
                                available_electrodes = NULL) {
  analysis_electrodes <- as.integer(analysis_electrodes)
  stim_electrodes <- as.integer(stim_electrodes)

  et <- as.data.frame(electrode_table)
  et$Electrode <- as.integer(et$Electrode)

  # Shaft assignment. Prefer surgical labels; if none are usable (e.g. the
  # subject has no localization), fall back to contiguous electrode-number runs.
  unusable <- function(v) {
    all(is.na(v) | trimws(as.character(v)) %in% c("", "NA", "NoLabel"))
  }
  if ("LabelPrefix" %in% names(et) && !unusable(et$LabelPrefix)) {
    shaft <- trimws(as.character(et$LabelPrefix))
  } else if ("Label" %in% names(et) && !unusable(et$Label)) {
    shaft <- trimws(gsub("[0-9]+$", "", as.character(et$Label)))
  } else {
    ord <- order(et$Electrode)
    grp <- integer(nrow(et))
    grp[ord] <- cumsum(c(TRUE, diff(et$Electrode[ord]) > 1L))
    shaft <- paste0("run", grp)
  }
  et$Shaft <- shaft

  if (is.null(available_electrodes)) {
    available_electrodes <- et$Electrode
  }
  available_electrodes <- as.integer(available_electrodes)

  empty <- data.frame(anode = integer(0), cathode = integer(0),
                      label = character(0), shaft = character(0),
                      bridged = logical(0), stringsAsFactors = FALSE)

  rows <- list()
  for (sh in unique(et$Shaft)) {
    sub <- et[et$Shaft == sh, , drop = FALSE]
    sub <- sub[order(sub$Electrode), , drop = FALSE]
    contacts <- sub$Electrode
    keep <- contacts[contacts %in% available_electrodes & !(contacts %in% stim_electrodes)]
    if (length(keep) < 2L) { next }
    for (j in seq_len(length(keep) - 1L)) {
      a <- keep[[j]]; b <- keep[[j + 1L]]
      # Only pair direct neighbours, or neighbours separated ONLY by stim
      # electrode(s). A gap containing any non-stim contact means we would be
      # bridging across a real electrode (or unrelated shaft), so skip it.
      between <- if (b - a > 1L) seq.int(a + 1L, b - 1L) else integer(0)
      if (length(between) && !all(between %in% stim_electrodes)) { next }
      if (!(a %in% analysis_electrodes || b %in% analysis_electrodes)) { next }
      rows[[length(rows) + 1L]] <- data.frame(
        anode = a, cathode = b,
        label = sprintf("%d-%d", a, b),
        shaft = sh,
        bridged = abs(b - a) > 1L,
        stringsAsFactors = FALSE
      )
    }
  }

  if (!length(rows)) { return(empty) }
  do.call(rbind, rows)
}


#' Apply bipolar pairs to a (samples x electrodes) signal matrix whose columns
#' correspond to `electrodes`. Returns a (samples x pairs) matrix of
#' `anode - cathode`; pairs whose contacts are not both present are dropped.
apply_bipolar_pairs <- function(signals, electrodes, pairs) {
  signals <- as.matrix(signals)
  electrodes <- as.integer(electrodes)
  n_pairs <- nrow(pairs)
  if (!n_pairs) { return(matrix(numeric(0), nrow = nrow(signals), ncol = 0)) }

  out <- matrix(NA_real_, nrow = nrow(signals), ncol = n_pairs)
  labs <- character(n_pairs)
  keep <- logical(n_pairs)
  for (i in seq_len(n_pairs)) {
    ai <- which(electrodes == pairs$anode[[i]])
    bi <- which(electrodes == pairs$cathode[[i]])
    if (length(ai) && length(bi)) {
      out[, i] <- signals[, ai[[1]]] - signals[, bi[[1]]]
      labs[[i]] <- pairs$label[[i]]
      keep[[i]] <- TRUE
    }
  }
  out <- out[, keep, drop = FALSE]
  colnames(out) <- labs[keep]
  out
}


# ---- Generalizable pulse profiling / clustering ------------------------------

#' Profile per-pulse snippets into `k` clusters via a pluggable `method`.
#' Designed to generalize (future `ravetools::bpc` or other methods can slot in
#' behind the same interface). Input is a (samples x pulses) matrix; `valid_rows`
#' restricts the rows used for PCA/clustering (the non-blanked samples).
#'
#' @return list(
#'   cluster            integer per-pulse cluster label (length = ncol(x)),
#'   clusters           the sorted unique cluster labels,
#'   profiles           (samples x n_clusters) per-cluster mean profiling curves,
#'   scores             (pulses x n_components) PC scores per input curve (or NULL),
#'   variance_explained variance fraction per PC (or NULL),
#'   method             the method used
#' )
profile_pulses <- function(x, k = 1L, method = c("pca_kmeans"),
                          n_components = 2L, valid_rows = NULL, ...) {
  method <- match.arg(method)
  x <- as.matrix(x)
  n_rows <- nrow(x)
  n_obs <- ncol(x)
  if (is.null(valid_rows)) { valid_rows <- seq_len(n_rows) }
  k <- max(1L, as.integer(k))
  n_components <- max(1L, as.integer(n_components))

  # observations x features (pulses x valid samples)
  X <- t(x[valid_rows, , drop = FALSE])
  ok <- stats::complete.cases(X)

  scores <- NULL
  variance_explained <- NULL
  if (sum(ok) > n_components && ncol(X) >= 2L) {
    npc <- min(n_components, ncol(X), sum(ok) - 1L)
    pr <- stats::prcomp(X[ok, , drop = FALSE], center = TRUE, scale. = FALSE, rank. = npc)
    sc <- matrix(NA_real_, nrow = n_obs, ncol = npc)
    sc[ok, ] <- pr$x[, seq_len(npc), drop = FALSE]
    colnames(sc) <- paste0("PC", seq_len(npc))
    scores <- sc
    variance_explained <- (pr$sdev^2) / sum(pr$sdev^2)
  }

  cluster <- rep(1L, n_obs)
  if (identical(method, "pca_kmeans") && k > 1L && !is.null(scores)) {
    kk <- min(k, sum(ok))
    if (kk > 1L) {
      cl_ok <- tryCatch(
        stats::kmeans(scores[ok, , drop = FALSE], centers = kk, ...)$cluster,
        error = function(e) rep(1L, sum(ok)))
      cluster[ok] <- as.integer(cl_ok)
      cluster[!ok] <- 1L
    }
  }

  ucl <- sort(unique(cluster))
  profiles <- vapply(ucl, function(cc) {
    rowMeans(x[, cluster == cc, drop = FALSE], na.rm = TRUE)
  }, numeric(n_rows))
  profiles <- matrix(profiles, nrow = n_rows)
  colnames(profiles) <- paste0("cluster", ucl)

  list(cluster = cluster, clusters = ucl, profiles = profiles, scores = scores,
       variance_explained = variance_explained, method = method)
}


#' Build one artifact template PER cluster using the MATLAB template math
#' (`compute_stim_template`: blank the direct-artifact rows + seam, then demean
#' the average of the remaining rows). With a single cluster this is identical to
#' the MATLAB single global template.
compute_cluster_templates <- function(snips, cluster, blank_width = 20L) {
  snips <- as.matrix(snips)
  cluster <- as.integer(cluster)
  ucl <- sort(unique(cluster))

  templates <- lapply(ucl, function(cc) {
    compute_stim_template(snips[, cluster == cc, drop = FALSE], blank_width = blank_width)
  })
  names(templates) <- paste0("cluster", ucl)

  list(
    templates = templates,
    clusters = ucl,
    cluster = cluster,
    valid_rows = templates[[1]]$valid_rows,
    blank_rows = templates[[1]]$blank_rows
  )
}


#' Per-cluster template subtraction + write-back + gap-fill. Like
#' `subtract_template_and_fill` but each pulse is corrected with the template of
#' its own cluster. `cluster_templates` is the output of `compute_cluster_templates`.
subtract_cluster_templates_and_fill <- function(signal, snips, onset_index, pre,
                                                cluster_templates,
                                                gap_fill_window = 101L) {
  signal <- as.numeric(signal)
  n <- length(signal)
  cleaned <- signal

  snips <- as.matrix(snips)
  n_rows <- nrow(snips)
  pre <- abs(as.integer(pre))

  cluster <- cluster_templates$cluster
  templates <- cluster_templates$templates
  onset_index <- as.integer(onset_index)

  for (i in seq_along(onset_index)) {
    tmpl <- templates[[paste0("cluster", cluster[[i]])]]
    valid_rows <- tmpl$valid_rows
    blank_rows <- tmpl$blank_rows

    vals <- snips[, i]
    vals[valid_rows] <- vals[valid_rows] - tmpl$template_valid
    vals[blank_rows] <- NA_real_

    idx <- onset_index[[i]] + (seq_len(n_rows) - 1L - pre)
    keep <- idx >= 1L & idx <= n
    cleaned[idx[keep]] <- vals[keep]
  }

  cleaned <- fill_missing_movmean(cleaned, window = gap_fill_window)
  cleaned <- fill_missing_nearest(cleaned)
  cleaned
}
