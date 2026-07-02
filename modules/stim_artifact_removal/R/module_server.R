
module_server <- function(input, output, session, ...) {


  # Local reactive values, used to store reactive event triggers
  local_reactives <- shiny::reactiveValues(
    update_outputs = NULL
  )

  # Local non-reactive values, used to store static variables
  local_data <- dipsaus::fastmap2()

  # get server tools to tweak
  server_tools <- get_default_handlers(session = session)


  # ---- Helpers ------------------------------------------------------------

  na_to_null <- function(x) {
    if (length(x) != 1 || is.na(x)) { return(NULL) }
    x
  }

  # Collect the pipeline-input values from the current UI state
  collect_pipeline_settings <- function() {
    list(
      recording_block      = input$recording_block,
      detection_source     = input$detection_source,
      trigger_electrode    = na_to_null(input$trigger_electrode),
      trigger_threshold    = input$trigger_threshold,
      pulse_duration       = input$pulse_duration,
      stim_frequency       = input$stim_frequency,
      stim_length          = input$stim_length,
      align_search_start   = input$align_search_start,
      align_search_end     = input$align_search_end,
      snip_window          = na_to_null(input$snip_window),
      template_window_pre  = input$template_window_pre,
      artifact_blank_width = input$artifact_blank_width,
      pca_enabled          = isTRUE(input$pca_enabled),
      pca_n_components      = input$pca_n_components,
      gap_fill_window      = input$gap_fill_window
    )
  }

  .output_ready <- function() {
    shiny::validate(
      shiny::need(
        !isFALSE(ravedash::watch_data_loaded()),
        message = "Data is not loaded"
      ),
      shiny::need(
        length(local_reactives$update_outputs) &&
          !isFALSE(local_reactives$update_outputs),
        message = "Please run the module first"
      )
    )
  }

  current_block <- function() {
    block <- input$recording_block
    if (length(block) != 1 || is.na(block) || !nzchar(block)) {
      return(NULL)
    }
    block
  }


  # ---- Main analysis ------------------------------------------------------

  run_analysis <- function() {
    if (!ravedash::watch_data_loaded()) { return() }

    pipeline$set_settings(.list = collect_pipeline_settings())

    dipsaus::shiny_alert2(
      title = "Running Pipeline...",
      text = ravedash::be_patient_text(),
      auto_close = FALSE,
      buttons = FALSE,
      icon = "info",
      session = session
    )

    on.exit({
      Sys.sleep(0.5)
      dipsaus::close_alert2(session = session)
    })

    tryCatch(
      {
        ravepipeline::logger("Scheduled: ", pipeline$pipeline_name,
                             level = "debug", reset_timer = TRUE)

        pipeline$run(
          scheduler = "none",
          type = "smart",
          names = c(
            "pulse_info_list",
            "aligned_pulse_list",
            "snippet_list",
            "template_list",
            "cleaned_signals"
          ),
          return_values = FALSE
        )

        ravepipeline::logger("Fulfilled: ", pipeline$pipeline_name, level = "debug")
        shidashi::clear_notifications(class = ns("pipeline-error"), session = session)

        shidashi::card_operate(title = "Data Selector", method = "collapse",
                               session = session)
        local_reactives$update_outputs <- Sys.time()
      },
      error = function(e) {
        ravepipeline::logger_error_condition(e)
        ravedash::error_notification(
          cond = e, autohide = FALSE,
          class = "pipeline-error", session = session
        )
      }
    )

    return()
  }

  shiny::bindEvent(
    ravedash::safe_observe({ run_analysis() }),
    input$run_btn, ignoreNULL = TRUE, ignoreInit = TRUE
  )

  # The ravedash footer button also runs the analysis
  shiny::bindEvent(
    ravedash::safe_observe({ run_analysis() }),
    server_tools$run_analysis_flag(),
    ignoreNULL = TRUE, ignoreInit = TRUE
  )


  # ---- Initialize UI when data is (re)loaded ------------------------------

  shiny::bindEvent(
    ravedash::safe_observe({
      loaded_flag <- ravedash::watch_data_loaded()
      if (!loaded_flag) { return() }

      new_repository <- pipeline$read("repository")
      if (!inherits(new_repository, "prepare_subject_raw_voltage_with_blocks")) {
        ravepipeline::logger(
          "Repository read from the pipeline, but it is not an instance of `prepare_subject_raw_voltage_with_blocks`. Abort initialization",
          level = "warning")
        return()
      }

      old_repository <- component_container$data$repository
      if (inherits(old_repository, "prepare_subject_raw_voltage_with_blocks")) {
        if (!attr(loaded_flag, "force") &&
            identical(old_repository$signature, new_repository$signature)) {
          return()
        }
      }

      # Reset preset UI & data
      component_container$reset_data()
      component_container$data$repository <- new_repository
      component_container$initialize_with_new_data()

      local_reactives$update_outputs <- FALSE

      all_blocks <- new_repository$blocks
      selected_block <- input$recording_block
      if (length(selected_block) != 1 || !selected_block %in% all_blocks) {
        selected_block <- all_blocks[[1]]
      }
      shiny::updateSelectInput(
        session = session,
        inputId = "recording_block",
        choices = all_blocks,
        selected = selected_block
      )

    }, priority = 1001),
    ravedash::watch_data_loaded(),
    ignoreNULL = FALSE, ignoreInit = FALSE
  )


  # ---- Apply / Export cleaned voltage -------------------------------------

  shiny::bindEvent(
    ravedash::safe_observe({
      export_name <- input$export_name
      if (!length(export_name)) { export_name <- "" }
      export_name <- trimws(export_name)
      if (!nzchar(export_name) || !grepl("^[a-zA-Z0-9_-]+$", export_name)) {
        stop("Export name must be non-blank and only contain letters, digits, '-' or '_'")
      }

      # Recompute cleaned voltage with the current settings, then export
      pipeline$set_settings(.list = collect_pipeline_settings())

      dipsaus::shiny_alert2(
        title = "Exporting cleaned voltage",
        text = ravedash::be_patient_text(),
        auto_close = FALSE, buttons = FALSE, icon = "info", session = session
      )

      res <- tryCatch({
        pipeline$run(names = "cleaned_signals", scheduler = "none",
                     type = "smart", return_values = FALSE)

        cleaned_signals <- pipeline$read("cleaned_signals")
        subject <- pipeline$read("subject")

        rave_dir <- dirname(subject$meta_path)
        out_dir <- file.path(rave_dir, "data", "cleaned_voltage", export_name)
        dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

        for (block in names(cleaned_signals)) {
          arr <- cleaned_signals[[block]]$`@impl`
          cleaned <- as.double(arr[drop = TRUE, dimnames = FALSE])
          sample_rate <- as.double(arr$get_header("sample_rate"))

          fpath <- file.path(out_dir, sprintf("%s.h5", block))
          tryCatch({
            raveio::save_h5(x = cleaned, file = fpath, name = "/cleaned",
                            replace = TRUE, new_file = TRUE, quiet = TRUE)
            raveio::save_h5(x = sample_rate, file = fpath, name = "/sample_rate",
                            replace = TRUE, new_file = FALSE, quiet = TRUE)
          }, error = function(e) {
            saveRDS(list(cleaned = cleaned, sample_rate = sample_rate),
                    file = file.path(out_dir, sprintf("%s.rds", block)))
          })
        }
        list(ok = TRUE, dir = out_dir)
      }, error = function(e) {
        list(ok = FALSE, msg = paste(conditionMessage(e), collapse = "\n"))
      })

      Sys.sleep(0.3)
      dipsaus::close_alert2(session = session)

      if (isTRUE(res$ok)) {
        dipsaus::shiny_alert2(
          title = "Success", icon = "success",
          text = sprintf("Cleaned voltage exported to:\n%s", res$dir),
          buttons = "OK", session = session
        )
      } else {
        stop(res$msg)
      }

    }, error_wrapper = "alert"),
    input$apply_btn, ignoreNULL = TRUE, ignoreInit = TRUE
  )


  # ---- Report -------------------------------------------------------------

  shiny::bindEvent(
    ravedash::safe_observe({
      block <- current_block()
      shiny::showModal(shiny::modalDialog(
        title = "Generate stim artifact removal report",
        easyClose = TRUE,
        shiny::selectInput(
          inputId = ns("report_block"), label = "Recording block",
          choices = if (length(block)) block else "",
          selected = block
        ),
        shiny::fluidRow(
          shiny::column(6L, shiny::numericInput(
            ns("report_time_start"), "View start (s)",
            value = if (length(input$plot_time_start)) input$plot_time_start else 0)),
          shiny::column(6L, shiny::numericInput(
            ns("report_time_end"), "View end (s)",
            value = if (length(input$plot_time_end)) input$plot_time_end else 5))
        ),
        footer = shiny::tagList(
          shiny::modalButton("Cancel"),
          dipsaus::actionButtonStyled(ns("do_generate_report"), "Generate")
        )
      ))
    }),
    input$open_report_modal, ignoreNULL = TRUE, ignoreInit = TRUE
  )

  shiny::bindEvent(
    ravedash::safe_observe({
      shiny::removeModal(session = session)

      subject <- pipeline$read("subject")

      job_id <- pipeline$generate_report(
        "stimRemoval",
        subject = subject,
        output_format = "html_document",
        theme = "spacelab",
        params = list(
          recording_block = input$report_block,
          time_range = c(input$report_time_start, input$report_time_end)
        ),
        code_folding = "none"
      )
      # MUST keep a reference, otherwise gc() kills the background process
      local_data$report_job_id <- job_id

      ravedash::show_notification(
        title = "Report scheduled",
        message = shiny::div(
          shiny::p("Report scheduled. Please check the subject report directory later: "),
          shiny::p(shiny::tags$code(class = "bg-secondary", subject$report_path))
        ),
        autohide = FALSE, type = "white",
        class = ns("_stim_report_notif"), session = session, close = TRUE
      )
    }, error_wrapper = "notification"),
    input$do_generate_report, ignoreNULL = TRUE, ignoreInit = TRUE
  )


  # ---- Register outputs ---------------------------------------------------

  output$figure_snippets <- shidashi::renderPlot2({
    .output_ready()
    block <- current_block()
    shiny::validate(shiny::need(length(block) == 1, "Select a recording block"))

    snippet_list <- pipeline$read("snippet_list")
    template_list <- pipeline$read("template_list")
    snip <- snippet_list[[block]]
    shiny::validate(shiny::need(
      is.list(snip) && is.matrix(snip$snips) && ncol(snip$snips) > 0,
      "No aligned pulses for this block"
    ))
    tmpl <- template_list[[block]]
    template_full <- if (is.list(tmpl)) tmpl$template$template_full else NULL

    plot_pulse_snippets_overlay(
      snips = snip$snips, sample_rate = snip$sample_rate,
      pre = snip$pre, template_full = template_full
    )
  })

  output$figure_template <- shidashi::renderPlot2({
    .output_ready()
    block <- current_block()
    shiny::validate(shiny::need(length(block) == 1, "Select a recording block"))

    template_list <- pipeline$read("template_list")
    tmpl <- template_list[[block]]
    shiny::validate(shiny::need(is.list(tmpl), "No template estimated for this block"))

    plot_template_waveform(
      template_full = tmpl$template$template_full,
      sample_rate = tmpl$sample_rate,
      blank_width = length(tmpl$template$blank_rows),
      pre = tmpl$pre
    )
  })

  output$figure_pca <- shidashi::renderPlot2({
    .output_ready()
    block <- current_block()
    shiny::validate(shiny::need(length(block) == 1, "Select a recording block"))

    template_list <- pipeline$read("template_list")
    tmpl <- template_list[[block]]
    shiny::validate(shiny::need(
      is.list(tmpl) && is.list(tmpl$pca) && !is.null(tmpl$pca$scores),
      "PCA not available (enable PCA and re-run)"
    ))

    plot_pca_scatter(tmpl$pca)
  })

  output$figure_before_after <- shidashi::renderPlot2({
    .output_ready()
    block <- current_block()
    shiny::validate(shiny::need(length(block) == 1, "Select a recording block"))

    loaded_signals <- pipeline$read("loaded_signals")
    cleaned_signals <- pipeline$read("cleaned_signals")
    shiny::validate(shiny::need(
      is.list(cleaned_signals) && !is.null(cleaned_signals[[block]]),
      "No cleaned trace for this block"
    ))

    raw_arr <- loaded_signals[[block]]$`@impl`
    cln_arr <- cleaned_signals[[block]]$`@impl`
    raw <- raw_arr[drop = TRUE, dimnames = FALSE]
    cln <- cln_arr[drop = TRUE, dimnames = FALSE]
    sample_rate <- cln_arr$get_header("sample_rate")

    time_range <- c(input$plot_time_start, input$plot_time_end)
    if (!length(time_range) || all(is.na(time_range))) {
      time_range <- c(NA, NA)
    }

    plot_before_after(raw, cln, sample_rate = sample_rate, time_range = time_range)
  })


}
