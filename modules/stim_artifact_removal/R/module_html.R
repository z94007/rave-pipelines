

module_html <- function() {

  shiny::fluidPage(
    shiny::fluidRow(

      shiny::column(
        width = 3L,
        shiny::div(
          class = "row screen-height overflow-y-scroll",
          shiny::column(
            width = 12L,

            # ---- Data selector ----
            ravedash::input_card(
              title = "Data Selector",

              shiny::selectInput(
                inputId = ns("recording_block"),
                label = "Recording block (for plots)",
                choices = "",
                selected = character()
              ),

              dipsaus::actionButtonStyled(
                inputId = ns("run_btn"),
                label = "Run artifact removal",
                width = "100%"
              )
            ),

            # ---- Detection ----
            ravedash::input_card(
              title = "Pulse Detection",

              shidashi::register_input(
                shiny::selectInput(
                  inputId = ns("detection_source"),
                  label = "Detection source",
                  choices = c("Auto (trigger, else epoch)" = "auto",
                              "Trigger / sync channel" = "trigger",
                              "Preloaded stim epoch" = "epoch"),
                  selected = "auto"
                ),
                inputId = "detection_source",
                update = "shiny::updateSelectInput(value=selected)",
                description = "Auto uses the trigger/sync channel when a trigger electrode is set, otherwise the preloaded stim epoch."
              ),

              shiny::conditionalPanel(
                condition = sprintf("input['%s'] !== 'epoch'", ns("detection_source")),
                shidashi::register_input(
                  shiny::numericInput(
                    inputId = ns("trigger_electrode"),
                    label = "Trigger electrode #",
                    value = NA, min = 1, step = 1
                  ),
                  inputId = "trigger_electrode",
                  update = "shiny::updateNumericInput",
                  description = "Electrode number of the sync/Events channel."
                ),
                shidashi::register_input(
                  shiny::numericInput(
                    inputId = ns("trigger_threshold"),
                    label = "Trigger threshold",
                    value = 1000, step = 50
                  ),
                  inputId = "trigger_threshold",
                  update = "shiny::updateNumericInput",
                  description = "Amplitude threshold on the trigger channel (MATLAB syncThresh)."
                ),
                shidashi::register_input(
                  shiny::numericInput(
                    inputId = ns("stim_length"),
                    label = "Train duration (s)",
                    value = 0.5, min = 0, step = 0.1
                  ),
                  inputId = "stim_length",
                  update = "shiny::updateNumericInput",
                  description = "Duration of each stimulation train (trigger mode)."
                )
              ),

              shidashi::register_input(
                shiny::numericInput(
                  inputId = ns("pulse_duration"),
                  label = "Pulse duration (ms)",
                  value = 0.5, min = 0, step = 0.1
                ),
                inputId = "pulse_duration",
                update = "shiny::updateNumericInput",
                description = "Rough single-pulse duration hint (can be slightly larger, not smaller, than the real pulse)."
              ),

              shidashi::register_input(
                shiny::numericInput(
                  inputId = ns("stim_frequency"),
                  label = "Stim frequency (Hz)",
                  value = 50, min = 1, step = 1
                ),
                inputId = "stim_frequency",
                update = "shiny::updateNumericInput",
                description = "Pulse rate; the per-pulse window is round(sample_rate / stim_frequency)."
              ),

              shiny::conditionalPanel(
                condition = sprintf("input['%s'] === 'epoch'", ns("detection_source")),
                shiny::helpText("Pulse onsets are read from the preloaded stimulation epoch (selected on the data loader).")
              )
            ),

            # ---- Alignment & template ----
            ravedash::input_card(
              title = "Alignment & Template",

              shidashi::register_input(
                shiny::numericInput(
                  inputId = ns("align_search_start"),
                  label = "Align search start row",
                  value = 15, min = 1, step = 1
                ),
                inputId = "align_search_start",
                update = "shiny::updateNumericInput",
                description = "First snippet row of the min/max alignment search window (MATLAB searchIdx start)."
              ),
              shidashi::register_input(
                shiny::numericInput(
                  inputId = ns("align_search_end"),
                  label = "Align search end row",
                  value = 20, min = 1, step = 1
                ),
                inputId = "align_search_end",
                update = "shiny::updateNumericInput",
                description = "Last snippet row of the min/max alignment search window (MATLAB searchIdx end)."
              ),
              shidashi::register_input(
                shiny::numericInput(
                  inputId = ns("snip_window"),
                  label = "Snippet window (samples, blank = auto)",
                  value = NA, min = 2, step = 1
                ),
                inputId = "snip_window",
                update = "shiny::updateNumericInput",
                description = "Samples per pulse window; blank uses round(sample_rate / stim_frequency)."
              ),
              shidashi::register_input(
                shiny::numericInput(
                  inputId = ns("template_window_pre"),
                  label = "Template window before onset (samples)",
                  value = 0, min = 0, step = 1
                ),
                inputId = "template_window_pre",
                update = "shiny::updateNumericInput",
                description = "Extra samples before onset included in the template window."
              ),
              shidashi::register_input(
                shiny::numericInput(
                  inputId = ns("artifact_blank_width"),
                  label = "Artifact blank width (samples)",
                  value = 20, min = 0, step = 1
                ),
                inputId = "artifact_blank_width",
                update = "shiny::updateNumericInput",
                description = "Leading samples of each snippet treated as the direct artifact (blanked, then gap-filled)."
              )
            ),

            # ---- PCA & gap fill ----
            ravedash::input_card(
              title = "PCA & Gap Fill",

              shidashi::register_input(
                shiny::checkboxInput(
                  inputId = ns("pca_enabled"),
                  label = "Run PCA inspection",
                  value = TRUE
                ),
                inputId = "pca_enabled",
                update = "shiny::updateCheckboxInput(value=value)",
                description = "Compute the pulse PCA scores (inspection only; not used for cleaning)."
              ),
              shiny::conditionalPanel(
                condition = sprintf("input['%s'] === true", ns("pca_enabled")),
                shidashi::register_input(
                  shiny::numericInput(
                    inputId = ns("pca_n_components"),
                    label = "PCA components",
                    value = 2, min = 1, step = 1
                  ),
                  inputId = "pca_n_components",
                  update = "shiny::updateNumericInput",
                  description = "Number of principal components to compute."
                )
              ),
              shidashi::register_input(
                shiny::numericInput(
                  inputId = ns("gap_fill_window"),
                  label = "Gap-fill window (samples)",
                  value = 101, min = 1, step = 2
                ),
                inputId = "gap_fill_window",
                update = "shiny::updateNumericInput",
                description = "Moving-average window used to fill the blanked artifact samples (MATLAB maWin)."
              )
            ),

            # ---- View & export ----
            ravedash::input_card(
              title = "View & Export",

              shidashi::register_input(
                shiny::numericInput(
                  inputId = ns("plot_time_start"),
                  label = "Before/after view start (s)",
                  value = 0, min = 0, step = 1
                ),
                inputId = "plot_time_start",
                update = "shiny::updateNumericInput",
                description = "Start of the before/after comparison window."
              ),
              shidashi::register_input(
                shiny::numericInput(
                  inputId = ns("plot_time_end"),
                  label = "Before/after view end (s)",
                  value = 5, min = 0, step = 0.5
                ),
                inputId = "plot_time_end",
                update = "shiny::updateNumericInput",
                description = "End of the before/after comparison window."
              ),
              shidashi::register_input(
                shiny::textInput(
                  inputId = ns("export_name"),
                  label = "Export name",
                  value = "cleaned"
                ),
                inputId = "export_name",
                update = "shiny::updateTextInput",
                description = "Name used when exporting the cleaned voltage back to the subject."
              ),
              dipsaus::actionButtonStyled(
                inputId = ns("apply_btn"),
                label = "Apply / Export cleaned voltage",
                type = "primary",
                width = "100%"
              ),
              shiny::hr(),
              shiny::actionButton(
                inputId = ns("open_report_modal"),
                label = "Generate report",
                width = "100%"
              )
            )

          )
        )
      ),

      shiny::column(
        width = 9L,
        shiny::div(
          class = "row screen-height overflow-y-scroll output-wrapper",
          shiny::column(
            width = 12L,

            ravedash::output_cardset(
              title = "Stim Artifact Removal",
              class_body = "no-padding fill-width min-height-450 height-550 resize-vertical",
              append_tools = FALSE,

              "Pulse Snippets" = shiny::div(
                class = "position-relative fill",
                shiny::plotOutput(
                  outputId = ns("figure_snippets"),
                  width = "100%", height = "100%"
                )
              ),

              "Template" = shiny::div(
                class = "position-relative fill",
                shiny::plotOutput(
                  outputId = ns("figure_template"),
                  width = "100%", height = "100%"
                )
              ),

              "PCA Scores" = shiny::div(
                class = "position-relative fill",
                shiny::plotOutput(
                  outputId = ns("figure_pca"),
                  width = "100%", height = "100%"
                )
              ),

              "Before / After" = shiny::div(
                class = "position-relative fill",
                shiny::plotOutput(
                  outputId = ns("figure_before_after"),
                  width = "100%", height = "100%"
                )
              )
            )

          )
        )
      )

    )
  )
}
