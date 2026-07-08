library(targets)
library(ravepipeline)
source("common.R", local = TRUE, chdir = TRUE)
._._env_._. <- environment()
._._env_._.$pipeline <- pipeline_from_path(".")
lapply(sort(list.files(
  "R/", ignore.case = TRUE,
  pattern = "^shared-.*\\.R", 
  full.names = TRUE
)), function(f) {
  source(f, local = ._._env_._., chdir = TRUE)
})
targets::tar_option_set(envir = ._._env_._.)
rm(._._env_._.)
...targets <- list(`__Check_settings_file` = targets::tar_target_raw("settings_path", 
    "settings.yaml", format = "file"), `__Load_settings` = targets::tar_target_raw("settings", 
    quote({
        yaml::read_yaml(settings_path)
    }), deps = "settings_path", cue = targets::tar_cue("always")), 
    input_export_name = targets::tar_target_raw("export_name", 
        quote({
            settings[["export_name"]]
        }), deps = "settings"), input_gap_fill_window = targets::tar_target_raw("gap_fill_window", 
        quote({
            settings[["gap_fill_window"]]
        }), deps = "settings"), input_template_electrodes = targets::tar_target_raw("template_electrodes", 
        quote({
            settings[["template_electrodes"]]
        }), deps = "settings"), input_pca_n_components = targets::tar_target_raw("pca_n_components", 
        quote({
            settings[["pca_n_components"]]
        }), deps = "settings"), input_n_clusters = targets::tar_target_raw("n_clusters", 
        quote({
            settings[["n_clusters"]]
        }), deps = "settings"), input_template_window_pre = targets::tar_target_raw("template_window_pre", 
        quote({
            settings[["template_window_pre"]]
        }), deps = "settings"), input_artifact_blank_width = targets::tar_target_raw("artifact_blank_width", 
        quote({
            settings[["artifact_blank_width"]]
        }), deps = "settings"), input_align_search_end = targets::tar_target_raw("align_search_end", 
        quote({
            settings[["align_search_end"]]
        }), deps = "settings"), input_align_search_start = targets::tar_target_raw("align_search_start", 
        quote({
            settings[["align_search_start"]]
        }), deps = "settings"), input_snip_window = targets::tar_target_raw("snip_window", 
        quote({
            settings[["snip_window"]]
        }), deps = "settings"), input_pulse_duration = targets::tar_target_raw("pulse_duration", 
        quote({
            settings[["pulse_duration"]]
        }), deps = "settings"), input_stim_train_duration = targets::tar_target_raw("stim_train_duration", 
        quote({
            settings[["stim_train_duration"]]
        }), deps = "settings"), input_stim_frequency = targets::tar_target_raw("stim_frequency", 
        quote({
            settings[["stim_frequency"]]
        }), deps = "settings"), input_stim_threshold = targets::tar_target_raw("stim_threshold", 
        quote({
            settings[["stim_threshold"]]
        }), deps = "settings"), input_event_channel = targets::tar_target_raw("event_channel", 
        quote({
            settings[["event_channel"]]
        }), deps = "settings"), input_stim_electrode = targets::tar_target_raw("stim_electrode", 
        quote({
            settings[["stim_electrode"]]
        }), deps = "settings"), input_analysis_electrodes = targets::tar_target_raw("analysis_electrodes", 
        quote({
            settings[["analysis_electrodes"]]
        }), deps = "settings"), input_analysis_block = targets::tar_target_raw("analysis_block", 
        quote({
            settings[["analysis_block"]]
        }), deps = "settings"), input_loaded_blocks = targets::tar_target_raw("loaded_blocks", 
        quote({
            settings[["loaded_blocks"]]
        }), deps = "settings"), input_loaded_electrodes = targets::tar_target_raw("loaded_electrodes", 
        quote({
            settings[["loaded_electrodes"]]
        }), deps = "settings"), input_subject_code = targets::tar_target_raw("subject_code", 
        quote({
            settings[["subject_code"]]
        }), deps = "settings"), input_project_name = targets::tar_target_raw("project_name", 
        quote({
            settings[["project_name"]]
        }), deps = "settings"), load_subject = targets::tar_target_raw(name = "subject", 
        command = quote({
            .__target_expr__. <- quote({
                subject <- ravecore::new_rave_subject(project_name = project_name, 
                  subject_code = subject_code, strict = FALSE)
            })
            tryCatch({
                eval(.__target_expr__.)
                return(subject)
            }, error = function(e) {
                asNamespace("ravepipeline")$resolve_pipeline_error(name = "subject", 
                  condition = e, expr = .__target_expr__.)
            })
        }), format = asNamespace("ravepipeline")$target_format_dynamic(name = NULL, 
            target_export = "subject", target_expr = quote({
                {
                  subject <- ravecore::new_rave_subject(project_name = project_name, 
                    subject_code = subject_code, strict = FALSE)
                }
                subject
            }), target_depends = c("project_name", "subject_code"
            )), deps = c("project_name", "subject_code"), cue = targets::tar_cue("thorough"), 
        pattern = NULL, iteration = "list"), clean_loaded_electrodes = targets::tar_target_raw(name = "loaded_electrode_clean", 
        command = quote({
            .__target_expr__. <- quote({
                loaded_electrode_clean <- dipsaus::parse_svec(loaded_electrodes)
                if (!length(loaded_electrode_clean)) {
                  loaded_electrode_clean <- subject$electrodes[subject$electrode_types == 
                    "LFP"]
                }
                loaded_electrode_clean <- sort(unique(as.integer(loaded_electrode_clean[loaded_electrode_clean %in% 
                  subject$electrodes])))
                if (!length(loaded_electrode_clean)) {
                  stop("No valid electrodes to load for this subject.")
                }
            })
            tryCatch({
                eval(.__target_expr__.)
                return(loaded_electrode_clean)
            }, error = function(e) {
                asNamespace("ravepipeline")$resolve_pipeline_error(name = "loaded_electrode_clean", 
                  condition = e, expr = .__target_expr__.)
            })
        }), format = asNamespace("ravepipeline")$target_format_dynamic(name = NULL, 
            target_export = "loaded_electrode_clean", target_expr = quote({
                {
                  loaded_electrode_clean <- dipsaus::parse_svec(loaded_electrodes)
                  if (!length(loaded_electrode_clean)) {
                    loaded_electrode_clean <- subject$electrodes[subject$electrode_types == 
                      "LFP"]
                  }
                  loaded_electrode_clean <- sort(unique(as.integer(loaded_electrode_clean[loaded_electrode_clean %in% 
                    subject$electrodes])))
                  if (!length(loaded_electrode_clean)) {
                    stop("No valid electrodes to load for this subject.")
                  }
                }
                loaded_electrode_clean
            }), target_depends = c("loaded_electrodes", "subject"
            )), deps = c("loaded_electrodes", "subject"), cue = targets::tar_cue("thorough"), 
        pattern = NULL, iteration = "list"), clean_analysis_electrodes = targets::tar_target_raw(name = "analysis_electrode_clean", 
        command = quote({
            .__target_expr__. <- quote({
                stim_e <- dipsaus::parse_svec(stim_electrode)
                requested <- dipsaus::parse_svec(analysis_electrodes)
                if (!length(requested)) {
                  requested <- setdiff(loaded_electrode_clean, 
                    stim_e)
                }
                lfp <- subject$electrodes[subject$electrode_types == 
                  "LFP"]
                analysis_electrode_clean <- sort(unique(as.integer(requested[requested %in% 
                  loaded_electrode_clean & requested %in% lfp])))
            })
            tryCatch({
                eval(.__target_expr__.)
                return(analysis_electrode_clean)
            }, error = function(e) {
                asNamespace("ravepipeline")$resolve_pipeline_error(name = "analysis_electrode_clean", 
                  condition = e, expr = .__target_expr__.)
            })
        }), format = asNamespace("ravepipeline")$target_format_dynamic(name = NULL, 
            target_export = "analysis_electrode_clean", target_expr = quote({
                {
                  stim_e <- dipsaus::parse_svec(stim_electrode)
                  requested <- dipsaus::parse_svec(analysis_electrodes)
                  if (!length(requested)) {
                    requested <- setdiff(loaded_electrode_clean, 
                      stim_e)
                  }
                  lfp <- subject$electrodes[subject$electrode_types == 
                    "LFP"]
                  analysis_electrode_clean <- sort(unique(as.integer(requested[requested %in% 
                    loaded_electrode_clean & requested %in% lfp])))
                }
                analysis_electrode_clean
            }), target_depends = c("stim_electrode", "analysis_electrodes", 
            "loaded_electrode_clean", "subject")), deps = c("stim_electrode", 
        "analysis_electrodes", "loaded_electrode_clean", "subject"
        ), cue = targets::tar_cue("thorough"), pattern = NULL, 
        iteration = "list"), clean_blocks = targets::tar_target_raw(name = "loaded_block_clean", 
        command = quote({
            .__target_expr__. <- quote({
                loaded_block_clean <- loaded_blocks
                if (!length(loaded_block_clean) || (length(loaded_block_clean) == 
                  1 && is.na(loaded_block_clean[[1]]))) {
                  loaded_block_clean <- subject$blocks
                }
                loaded_block_clean <- intersect(as.character(unlist(loaded_block_clean)), 
                  subject$blocks)
                if (!length(loaded_block_clean)) {
                  loaded_block_clean <- subject$blocks
                }
                if (!isTRUE(as.character(analysis_block) %in% 
                  loaded_block_clean)) {
                  stop(sprintf("analysis_block '%s' is not among the loaded blocks: %s", 
                    analysis_block, paste(loaded_block_clean, 
                      collapse = ", ")))
                }
            })
            tryCatch({
                eval(.__target_expr__.)
                return(loaded_block_clean)
            }, error = function(e) {
                asNamespace("ravepipeline")$resolve_pipeline_error(name = "loaded_block_clean", 
                  condition = e, expr = .__target_expr__.)
            })
        }), format = asNamespace("ravepipeline")$target_format_dynamic(name = NULL, 
            target_export = "loaded_block_clean", target_expr = quote({
                {
                  loaded_block_clean <- loaded_blocks
                  if (!length(loaded_block_clean) || (length(loaded_block_clean) == 
                    1 && is.na(loaded_block_clean[[1]]))) {
                    loaded_block_clean <- subject$blocks
                  }
                  loaded_block_clean <- intersect(as.character(unlist(loaded_block_clean)), 
                    subject$blocks)
                  if (!length(loaded_block_clean)) {
                    loaded_block_clean <- subject$blocks
                  }
                  if (!isTRUE(as.character(analysis_block) %in% 
                    loaded_block_clean)) {
                    stop(sprintf("analysis_block '%s' is not among the loaded blocks: %s", 
                      analysis_block, paste(loaded_block_clean, 
                        collapse = ", ")))
                  }
                }
                loaded_block_clean
            }), target_depends = c("loaded_blocks", "subject", 
            "analysis_block")), deps = c("loaded_blocks", "subject", 
        "analysis_block"), cue = targets::tar_cue("thorough"), 
        pattern = NULL, iteration = "list"), load_repository = targets::tar_target_raw(name = "repository", 
        command = quote({
            .__target_expr__. <- quote({
                repository <- ravecore::prepare_subject_raw_voltage_with_blocks(subject = subject, 
                  electrodes = loaded_electrode_clean, blocks = loaded_block_clean, 
                  downsample = NA)
            })
            tryCatch({
                eval(.__target_expr__.)
                return(repository)
            }, error = function(e) {
                asNamespace("ravepipeline")$resolve_pipeline_error(name = "repository", 
                  condition = e, expr = .__target_expr__.)
            })
        }), format = asNamespace("ravepipeline")$target_format_dynamic(name = NULL, 
            target_export = "repository", target_expr = quote({
                {
                  repository <- ravecore::prepare_subject_raw_voltage_with_blocks(subject = subject, 
                    electrodes = loaded_electrode_clean, blocks = loaded_block_clean, 
                    downsample = NA)
                }
                repository
            }), target_depends = c("subject", "loaded_electrode_clean", 
            "loaded_block_clean")), deps = c("subject", "loaded_electrode_clean", 
        "loaded_block_clean"), cue = targets::tar_cue("thorough"), 
        pattern = NULL, iteration = "list"), load_signals = targets::tar_target_raw(name = "loaded_signals", 
        command = quote({
            .__target_expr__. <- quote({
                filearray_root <- file.path(pipeline$pipeline_path, 
                  "data", "raw-voltage")
                container <- repository$get_container()
                loaded_signals <- structure(names = loaded_block_clean, 
                  lapply(loaded_block_clean, function(block) {
                    ex <- extract_block_signal(container[[block]], 
                      loaded_electrode_clean)
                    new_rave_filearray(filebase = file.path(filearray_root, 
                      block), data = ex$data, dimnames_list = list(Time = ex$time, 
                      Electrode = loaded_electrode_clean), headers = list(subject_id = repository$subject$subject_id, 
                      block = block, sample_rate = ex$sample_rate, 
                      max_duration = max(ex$time)))
                  }))
            })
            tryCatch({
                eval(.__target_expr__.)
                return(loaded_signals)
            }, error = function(e) {
                asNamespace("ravepipeline")$resolve_pipeline_error(name = "loaded_signals", 
                  condition = e, expr = .__target_expr__.)
            })
        }), format = asNamespace("ravepipeline")$target_format_dynamic(name = NULL, 
            target_export = "loaded_signals", target_expr = quote({
                {
                  filearray_root <- file.path(pipeline$pipeline_path, 
                    "data", "raw-voltage")
                  container <- repository$get_container()
                  loaded_signals <- structure(names = loaded_block_clean, 
                    lapply(loaded_block_clean, function(block) {
                      ex <- extract_block_signal(container[[block]], 
                        loaded_electrode_clean)
                      new_rave_filearray(filebase = file.path(filearray_root, 
                        block), data = ex$data, dimnames_list = list(Time = ex$time, 
                        Electrode = loaded_electrode_clean), 
                        headers = list(subject_id = repository$subject$subject_id, 
                          block = block, sample_rate = ex$sample_rate, 
                          max_duration = max(ex$time)))
                    }))
                }
                loaded_signals
            }), target_depends = c("repository", "loaded_block_clean", 
            "loaded_electrode_clean")), deps = c("repository", 
        "loaded_block_clean", "loaded_electrode_clean"), cue = targets::tar_cue("thorough"), 
        pattern = NULL, iteration = "list"), detect_pulses = targets::tar_target_raw(name = "pulse_info", 
        command = quote({
            .__target_expr__. <- quote({
                ec <- suppressWarnings(as.integer(dipsaus::parse_svec(event_channel)))
                ec <- ec[is.finite(ec)]
                if (!length(ec)) {
                  ec <- tryCatch(auto_detect_event_channel(subject, 
                    analysis_block), error = function(e) NULL)
                }
                if (length(ec) && !is.na(ec[[1]]) && ec[[1]] %in% 
                  subject$electrodes) {
                  ev <- load_stim_channel(repository, ec[[1]], 
                    block = analysis_block)
                  info <- detect_pulses_from_events(events_signal = ev$data, 
                    sample_rate = ev$sample_rate, stim_frequency = as.numeric(stim_frequency), 
                    stim_train_duration = as.numeric(stim_train_duration), 
                    pulse_duration_sec = as.numeric(pulse_duration)/1000)
                  info$sample_rate <- ev$sample_rate
                  info$detection_source <- "events"
                  info$event_channel <- ec[[1]]
                } else {
                  stim <- load_stim_channel(repository, stim_electrode, 
                    block = analysis_block)
                  info <- detect_pulses_from_stim_channel(signal = stim$data, 
                    sample_rate = stim$sample_rate, threshold = as.numeric(stim_threshold), 
                    stim_frequency = as.numeric(stim_frequency), 
                    refractory_frac = 0.8, pulse_duration_sec = as.numeric(pulse_duration)/1000)
                  info$sample_rate <- stim$sample_rate
                  info$detection_source <- "stim_electrode"
                  info$event_channel <- NA_integer_
                }
                info$block <- as.character(analysis_block)
                info$stim_electrode <- stim_electrode
                pulse_info <- info
            })
            tryCatch({
                eval(.__target_expr__.)
                return(pulse_info)
            }, error = function(e) {
                asNamespace("ravepipeline")$resolve_pipeline_error(name = "pulse_info", 
                  condition = e, expr = .__target_expr__.)
            })
        }), format = asNamespace("ravepipeline")$target_format_dynamic(name = NULL, 
            target_export = "pulse_info", target_expr = quote({
                {
                  ec <- suppressWarnings(as.integer(dipsaus::parse_svec(event_channel)))
                  ec <- ec[is.finite(ec)]
                  if (!length(ec)) {
                    ec <- tryCatch(auto_detect_event_channel(subject, 
                      analysis_block), error = function(e) NULL)
                  }
                  if (length(ec) && !is.na(ec[[1]]) && ec[[1]] %in% 
                    subject$electrodes) {
                    ev <- load_stim_channel(repository, ec[[1]], 
                      block = analysis_block)
                    info <- detect_pulses_from_events(events_signal = ev$data, 
                      sample_rate = ev$sample_rate, stim_frequency = as.numeric(stim_frequency), 
                      stim_train_duration = as.numeric(stim_train_duration), 
                      pulse_duration_sec = as.numeric(pulse_duration)/1000)
                    info$sample_rate <- ev$sample_rate
                    info$detection_source <- "events"
                    info$event_channel <- ec[[1]]
                  } else {
                    stim <- load_stim_channel(repository, stim_electrode, 
                      block = analysis_block)
                    info <- detect_pulses_from_stim_channel(signal = stim$data, 
                      sample_rate = stim$sample_rate, threshold = as.numeric(stim_threshold), 
                      stim_frequency = as.numeric(stim_frequency), 
                      refractory_frac = 0.8, pulse_duration_sec = as.numeric(pulse_duration)/1000)
                    info$sample_rate <- stim$sample_rate
                    info$detection_source <- "stim_electrode"
                    info$event_channel <- NA_integer_
                  }
                  info$block <- as.character(analysis_block)
                  info$stim_electrode <- stim_electrode
                  pulse_info <- info
                }
                pulse_info
            }), target_depends = c("event_channel", "subject", 
            "analysis_block", "repository", "stim_frequency", 
            "stim_train_duration", "pulse_duration", "stim_electrode", 
            "stim_threshold")), deps = c("event_channel", "subject", 
        "analysis_block", "repository", "stim_frequency", "stim_train_duration", 
        "pulse_duration", "stim_electrode", "stim_threshold"), 
        cue = targets::tar_cue("thorough"), pattern = NULL, iteration = "list"), 
    build_bipolar_pairs = targets::tar_target_raw(name = "bipolar_pairs", 
        command = quote({
            .__target_expr__. <- quote({
                electrode_table <- subject$get_electrode_table()
                stim_e <- dipsaus::parse_svec(stim_electrode)
                bipolar_pairs <- build_bipolar_pairs(electrode_table = electrode_table, 
                  analysis_electrodes = analysis_electrode_clean, 
                  stim_electrodes = stim_e, available_electrodes = loaded_electrode_clean)
            })
            tryCatch({
                eval(.__target_expr__.)
                return(bipolar_pairs)
            }, error = function(e) {
                asNamespace("ravepipeline")$resolve_pipeline_error(name = "bipolar_pairs", 
                  condition = e, expr = .__target_expr__.)
            })
        }), format = asNamespace("ravepipeline")$target_format_dynamic(name = NULL, 
            target_export = "bipolar_pairs", target_expr = quote({
                {
                  electrode_table <- subject$get_electrode_table()
                  stim_e <- dipsaus::parse_svec(stim_electrode)
                  bipolar_pairs <- build_bipolar_pairs(electrode_table = electrode_table, 
                    analysis_electrodes = analysis_electrode_clean, 
                    stim_electrodes = stim_e, available_electrodes = loaded_electrode_clean)
                }
                bipolar_pairs
            }), target_depends = c("subject", "stim_electrode", 
            "analysis_electrode_clean", "loaded_electrode_clean"
            )), deps = c("subject", "stim_electrode", "analysis_electrode_clean", 
        "loaded_electrode_clean"), cue = targets::tar_cue("thorough"), 
        pattern = NULL, iteration = "list"), apply_bipolar = targets::tar_target_raw(name = "bipolar_signals", 
        command = quote({
            .__target_expr__. <- quote({
                block <- as.character(analysis_block)
                arr <- loaded_signals[[block]]$`@impl`
                sample_rate <- arr$get_header("sample_rate")
                signals <- arr[, , drop = FALSE, dimnames = FALSE]
                time <- as.numeric(dimnames(arr)$Time)
                bip <- apply_bipolar_pairs(signals, loaded_electrode_clean, 
                  bipolar_pairs)
                filearray_root <- file.path(pipeline$pipeline_path, 
                  "data", "bipolar-voltage")
                if (ncol(bip) > 0) {
                  bipolar_signals <- new_rave_filearray(filebase = file.path(filearray_root, 
                    block), data = bip, dimnames_list = list(Time = time, 
                    Electrode = colnames(bip)), headers = list(block = block, 
                    sample_rate = sample_rate))
                } else {
                  bipolar_signals <- NULL
                }
            })
            tryCatch({
                eval(.__target_expr__.)
                return(bipolar_signals)
            }, error = function(e) {
                asNamespace("ravepipeline")$resolve_pipeline_error(name = "bipolar_signals", 
                  condition = e, expr = .__target_expr__.)
            })
        }), format = asNamespace("ravepipeline")$target_format_dynamic(name = NULL, 
            target_export = "bipolar_signals", target_expr = quote({
                {
                  block <- as.character(analysis_block)
                  arr <- loaded_signals[[block]]$`@impl`
                  sample_rate <- arr$get_header("sample_rate")
                  signals <- arr[, , drop = FALSE, dimnames = FALSE]
                  time <- as.numeric(dimnames(arr)$Time)
                  bip <- apply_bipolar_pairs(signals, loaded_electrode_clean, 
                    bipolar_pairs)
                  filearray_root <- file.path(pipeline$pipeline_path, 
                    "data", "bipolar-voltage")
                  if (ncol(bip) > 0) {
                    bipolar_signals <- new_rave_filearray(filebase = file.path(filearray_root, 
                      block), data = bip, dimnames_list = list(Time = time, 
                      Electrode = colnames(bip)), headers = list(block = block, 
                      sample_rate = sample_rate))
                  } else {
                    bipolar_signals <- NULL
                  }
                }
                bipolar_signals
            }), target_depends = c("analysis_block", "loaded_signals", 
            "loaded_electrode_clean", "bipolar_pairs")), deps = c("analysis_block", 
        "loaded_signals", "loaded_electrode_clean", "bipolar_pairs"
        ), cue = targets::tar_cue("thorough"), pattern = NULL, 
        iteration = "list"), build_snippets = targets::tar_target_raw(name = "snippet_list", 
        command = quote({
            .__target_expr__. <- quote({
                block <- as.character(analysis_block)
                sample_rate <- pulse_info$sample_rate
                pre <- abs(as.integer(template_window_pre))
                win <- suppressWarnings(as.integer(snip_window))
                if (!length(win) || is.na(win) || win < 2L) win <- round(sample_rate/as.numeric(stim_frequency))
                snippet_list <- list()
                if (!is.null(bipolar_signals) && isTRUE(pulse_info$n_pulses > 
                  0)) {
                  barr <- bipolar_signals$`@impl`
                  labs <- dimnames(barr)$Electrode
                  snippet_list <- structure(names = labs, lapply(seq_along(labs), 
                    function(j) {
                      trace <- barr[, j, drop = TRUE, dimnames = FALSE]
                      list(snips = extract_snippets(trace, pulse_info$onset_index, 
                        snip_window = win, pre = pre), onset_index = pulse_info$onset_index, 
                        pre = pre, snip_window = win, sample_rate = sample_rate)
                    }))
                }
            })
            tryCatch({
                eval(.__target_expr__.)
                return(snippet_list)
            }, error = function(e) {
                asNamespace("ravepipeline")$resolve_pipeline_error(name = "snippet_list", 
                  condition = e, expr = .__target_expr__.)
            })
        }), format = asNamespace("ravepipeline")$target_format_dynamic(name = NULL, 
            target_export = "snippet_list", target_expr = quote({
                {
                  block <- as.character(analysis_block)
                  sample_rate <- pulse_info$sample_rate
                  pre <- abs(as.integer(template_window_pre))
                  win <- suppressWarnings(as.integer(snip_window))
                  if (!length(win) || is.na(win) || win < 2L) win <- round(sample_rate/as.numeric(stim_frequency))
                  snippet_list <- list()
                  if (!is.null(bipolar_signals) && isTRUE(pulse_info$n_pulses > 
                    0)) {
                    barr <- bipolar_signals$`@impl`
                    labs <- dimnames(barr)$Electrode
                    snippet_list <- structure(names = labs, lapply(seq_along(labs), 
                      function(j) {
                        trace <- barr[, j, drop = TRUE, dimnames = FALSE]
                        list(snips = extract_snippets(trace, 
                          pulse_info$onset_index, snip_window = win, 
                          pre = pre), onset_index = pulse_info$onset_index, 
                          pre = pre, snip_window = win, sample_rate = sample_rate)
                      }))
                  }
                }
                snippet_list
            }), target_depends = c("analysis_block", "pulse_info", 
            "template_window_pre", "snip_window", "stim_frequency", 
            "bipolar_signals")), deps = c("analysis_block", "pulse_info", 
        "template_window_pre", "snip_window", "stim_frequency", 
        "bipolar_signals"), cue = targets::tar_cue("thorough"), 
        pattern = NULL, iteration = "list"), align_pulses = targets::tar_target_raw(name = "aligned_pulse_list", 
        command = quote({
            .__target_expr__. <- quote({
                search_start <- as.integer(align_search_start)
                search_end <- as.integer(align_search_end)
                pulse_dur_samples <- round((as.numeric(pulse_duration)/1000) * 
                  pulse_info$sample_rate)
                aligned_pulse_list <- list()
                if (length(snippet_list) && !is.null(bipolar_signals)) {
                  barr <- bipolar_signals$`@impl`
                  labs <- names(snippet_list)
                  aligned_pulse_list <- structure(names = labs, 
                    lapply(seq_along(labs), function(j) {
                      snip <- snippet_list[[j]]
                      trace <- barr[, j, drop = TRUE, dimnames = FALSE]
                      al <- align_pulses_minmax(signal = trace, 
                        onset_index = snip$onset_index, snip_window = snip$snip_window, 
                        search_start = search_start, search_end = search_end, 
                        pulse_duration_samples = pulse_dur_samples)
                      snips <- extract_snippets(trace, al$onset_index, 
                        snip_window = snip$snip_window, pre = snip$pre)
                      list(snips = snips, onset_index = al$onset_index, 
                        n_pulses = al$n_pulses, pre = snip$pre, 
                        snip_window = snip$snip_window, sample_rate = snip$sample_rate)
                    }))
                }
            })
            tryCatch({
                eval(.__target_expr__.)
                return(aligned_pulse_list)
            }, error = function(e) {
                asNamespace("ravepipeline")$resolve_pipeline_error(name = "aligned_pulse_list", 
                  condition = e, expr = .__target_expr__.)
            })
        }), format = asNamespace("ravepipeline")$target_format_dynamic(name = NULL, 
            target_export = "aligned_pulse_list", target_expr = quote({
                {
                  search_start <- as.integer(align_search_start)
                  search_end <- as.integer(align_search_end)
                  pulse_dur_samples <- round((as.numeric(pulse_duration)/1000) * 
                    pulse_info$sample_rate)
                  aligned_pulse_list <- list()
                  if (length(snippet_list) && !is.null(bipolar_signals)) {
                    barr <- bipolar_signals$`@impl`
                    labs <- names(snippet_list)
                    aligned_pulse_list <- structure(names = labs, 
                      lapply(seq_along(labs), function(j) {
                        snip <- snippet_list[[j]]
                        trace <- barr[, j, drop = TRUE, dimnames = FALSE]
                        al <- align_pulses_minmax(signal = trace, 
                          onset_index = snip$onset_index, snip_window = snip$snip_window, 
                          search_start = search_start, search_end = search_end, 
                          pulse_duration_samples = pulse_dur_samples)
                        snips <- extract_snippets(trace, al$onset_index, 
                          snip_window = snip$snip_window, pre = snip$pre)
                        list(snips = snips, onset_index = al$onset_index, 
                          n_pulses = al$n_pulses, pre = snip$pre, 
                          snip_window = snip$snip_window, sample_rate = snip$sample_rate)
                      }))
                  }
                }
                aligned_pulse_list
            }), target_depends = c("align_search_start", "align_search_end", 
            "pulse_duration", "pulse_info", "snippet_list", "bipolar_signals"
            )), deps = c("align_search_start", "align_search_end", 
        "pulse_duration", "pulse_info", "snippet_list", "bipolar_signals"
        ), cue = targets::tar_cue("thorough"), pattern = NULL, 
        iteration = "list"), compute_template = targets::tar_target_raw(name = "template_list", 
        command = quote({
            .__target_expr__. <- quote({
                k <- max(1L, as.integer(n_clusters))
                blank_width <- as.integer(artifact_blank_width)
                ncomp <- max(1L, as.integer(pca_n_components))
                template_list <- list()
                if (length(aligned_pulse_list)) {
                  labs <- names(aligned_pulse_list)
                  template_list <- structure(names = labs, lapply(seq_along(labs), 
                    function(j) {
                      al <- aligned_pulse_list[[j]]
                      if (!isTRUE(ncol(al$snips) > 0)) return(NULL)
                      n_rows <- nrow(al$snips)
                      valid_rows <- setdiff(seq_len(n_rows), 
                        unique(c(seq_len(blank_width), n_rows)))
                      profile <- profile_pulses(al$snips, k = k, 
                        method = "pca_kmeans", n_components = ncomp, 
                        valid_rows = valid_rows)
                      ctempl <- compute_cluster_templates(al$snips, 
                        profile$cluster, blank_width = blank_width)
                      template_full <- vapply(ctempl$templates, 
                        function(t) t$template_full, numeric(n_rows))
                      list(profile = profile, cluster_templates = ctempl, 
                        template_full = matrix(template_full, 
                          nrow = n_rows, dimnames = list(NULL, 
                            names(ctempl$templates))), blank_rows = ctempl$blank_rows, 
                        sample_rate = al$sample_rate, pre = al$pre)
                    }))
                }
            })
            tryCatch({
                eval(.__target_expr__.)
                return(template_list)
            }, error = function(e) {
                asNamespace("ravepipeline")$resolve_pipeline_error(name = "template_list", 
                  condition = e, expr = .__target_expr__.)
            })
        }), format = asNamespace("ravepipeline")$target_format_dynamic(name = NULL, 
            target_export = "template_list", target_expr = quote({
                {
                  k <- max(1L, as.integer(n_clusters))
                  blank_width <- as.integer(artifact_blank_width)
                  ncomp <- max(1L, as.integer(pca_n_components))
                  template_list <- list()
                  if (length(aligned_pulse_list)) {
                    labs <- names(aligned_pulse_list)
                    template_list <- structure(names = labs, 
                      lapply(seq_along(labs), function(j) {
                        al <- aligned_pulse_list[[j]]
                        if (!isTRUE(ncol(al$snips) > 0)) return(NULL)
                        n_rows <- nrow(al$snips)
                        valid_rows <- setdiff(seq_len(n_rows), 
                          unique(c(seq_len(blank_width), n_rows)))
                        profile <- profile_pulses(al$snips, k = k, 
                          method = "pca_kmeans", n_components = ncomp, 
                          valid_rows = valid_rows)
                        ctempl <- compute_cluster_templates(al$snips, 
                          profile$cluster, blank_width = blank_width)
                        template_full <- vapply(ctempl$templates, 
                          function(t) t$template_full, numeric(n_rows))
                        list(profile = profile, cluster_templates = ctempl, 
                          template_full = matrix(template_full, 
                            nrow = n_rows, dimnames = list(NULL, 
                              names(ctempl$templates))), blank_rows = ctempl$blank_rows, 
                          sample_rate = al$sample_rate, pre = al$pre)
                      }))
                  }
                }
                template_list
            }), target_depends = c("n_clusters", "artifact_blank_width", 
            "pca_n_components", "aligned_pulse_list")), deps = c("n_clusters", 
        "artifact_blank_width", "pca_n_components", "aligned_pulse_list"
        ), cue = targets::tar_cue("thorough"), pattern = NULL, 
        iteration = "list"), clean_signals = targets::tar_target_raw(name = "cleaned_signals", 
        command = quote({
            .__target_expr__. <- quote({
                block <- as.character(analysis_block)
                gap_win <- as.integer(gap_fill_window)
                blank_width <- as.integer(artifact_blank_width)
                filearray_root <- file.path(pipeline$pipeline_path, 
                  "data", "cleaned-voltage")
                te <- dipsaus::parse_svec(template_electrodes)
                pair_is_near <- function(lab) {
                  if (!length(te)) {
                    return(TRUE)
                  }
                  row <- bipolar_pairs[bipolar_pairs$label == 
                    lab, , drop = FALSE]
                  if (!nrow(row)) {
                    return(TRUE)
                  }
                  isTRUE(row$anode[[1]] %in% te) || isTRUE(row$cathode[[1]] %in% 
                    te)
                }
                cleaned_signals <- list()
                if (length(aligned_pulse_list) && !is.null(bipolar_signals)) {
                  barr <- bipolar_signals$`@impl`
                  labs <- names(aligned_pulse_list)
                  time <- as.numeric(dimnames(barr)$Time)
                  cleaned_signals <- structure(names = labs, 
                    lapply(seq_along(labs), function(j) {
                      lab <- labs[[j]]
                      al <- aligned_pulse_list[[j]]
                      tmpl <- template_list[[lab]]
                      trace <- barr[, j, drop = TRUE, dimnames = FALSE]
                      near <- pair_is_near(lab)
                      if (!isTRUE(al$n_pulses > 0)) {
                        cleaned <- as.numeric(trace)
                        method <- "none"
                      } else if (near && !is.null(tmpl)) {
                        cleaned <- subtract_cluster_templates_and_fill(signal = trace, 
                          snips = al$snips, onset_index = al$onset_index, 
                          pre = al$pre, cluster_templates = tmpl$cluster_templates, 
                          gap_fill_window = gap_win)
                        method <- "bipolar+template"
                      } else {
                        cleaned <- blank_direct_artifact_and_fill(signal = trace, 
                          onset_index = al$onset_index, snip_window = al$snip_window, 
                          blank_width = blank_width, pre = al$pre, 
                          gap_fill_window = gap_win)
                        method <- "bipolar+direct"
                      }
                      new_rave_filearray(filebase = file.path(filearray_root, 
                        sprintf("%s_%s", block, lab)), data = matrix(cleaned, 
                        ncol = 1L), dimnames_list = list(Time = time, 
                        Electrode = lab), headers = list(block = block, 
                        channel = lab, sample_rate = barr$get_header("sample_rate"), 
                        n_pulses = al$n_pulses, cleaning_method = method))
                    }))
                }
            })
            tryCatch({
                eval(.__target_expr__.)
                return(cleaned_signals)
            }, error = function(e) {
                asNamespace("ravepipeline")$resolve_pipeline_error(name = "cleaned_signals", 
                  condition = e, expr = .__target_expr__.)
            })
        }), format = asNamespace("ravepipeline")$target_format_dynamic(name = NULL, 
            target_export = "cleaned_signals", target_expr = quote({
                {
                  block <- as.character(analysis_block)
                  gap_win <- as.integer(gap_fill_window)
                  blank_width <- as.integer(artifact_blank_width)
                  filearray_root <- file.path(pipeline$pipeline_path, 
                    "data", "cleaned-voltage")
                  te <- dipsaus::parse_svec(template_electrodes)
                  pair_is_near <- function(lab) {
                    if (!length(te)) {
                      return(TRUE)
                    }
                    row <- bipolar_pairs[bipolar_pairs$label == 
                      lab, , drop = FALSE]
                    if (!nrow(row)) {
                      return(TRUE)
                    }
                    isTRUE(row$anode[[1]] %in% te) || isTRUE(row$cathode[[1]] %in% 
                      te)
                  }
                  cleaned_signals <- list()
                  if (length(aligned_pulse_list) && !is.null(bipolar_signals)) {
                    barr <- bipolar_signals$`@impl`
                    labs <- names(aligned_pulse_list)
                    time <- as.numeric(dimnames(barr)$Time)
                    cleaned_signals <- structure(names = labs, 
                      lapply(seq_along(labs), function(j) {
                        lab <- labs[[j]]
                        al <- aligned_pulse_list[[j]]
                        tmpl <- template_list[[lab]]
                        trace <- barr[, j, drop = TRUE, dimnames = FALSE]
                        near <- pair_is_near(lab)
                        if (!isTRUE(al$n_pulses > 0)) {
                          cleaned <- as.numeric(trace)
                          method <- "none"
                        } else if (near && !is.null(tmpl)) {
                          cleaned <- subtract_cluster_templates_and_fill(signal = trace, 
                            snips = al$snips, onset_index = al$onset_index, 
                            pre = al$pre, cluster_templates = tmpl$cluster_templates, 
                            gap_fill_window = gap_win)
                          method <- "bipolar+template"
                        } else {
                          cleaned <- blank_direct_artifact_and_fill(signal = trace, 
                            onset_index = al$onset_index, snip_window = al$snip_window, 
                            blank_width = blank_width, pre = al$pre, 
                            gap_fill_window = gap_win)
                          method <- "bipolar+direct"
                        }
                        new_rave_filearray(filebase = file.path(filearray_root, 
                          sprintf("%s_%s", block, lab)), data = matrix(cleaned, 
                          ncol = 1L), dimnames_list = list(Time = time, 
                          Electrode = lab), headers = list(block = block, 
                          channel = lab, sample_rate = barr$get_header("sample_rate"), 
                          n_pulses = al$n_pulses, cleaning_method = method))
                      }))
                  }
                }
                cleaned_signals
            }), target_depends = c("analysis_block", "gap_fill_window", 
            "artifact_blank_width", "template_electrodes", "bipolar_pairs", 
            "aligned_pulse_list", "bipolar_signals", "template_list"
            )), deps = c("analysis_block", "gap_fill_window", 
        "artifact_blank_width", "template_electrodes", "bipolar_pairs", 
        "aligned_pulse_list", "bipolar_signals", "template_list"
        ), cue = targets::tar_cue("thorough"), pattern = NULL, 
        iteration = "list"))
