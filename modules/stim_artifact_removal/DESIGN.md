# Stim Artifact Removal — Design

Design record for the `stim_artifact_removal` RAVE pipeline. Captures *why* the pipeline is
shaped the way it is, distilled from the MATLAB prototype (`tmp/artifact_rej.m`) and the
design review with the author. Status tags: **[Built]** shipped and verified, **[Designed]**
agreed but not yet implemented, **[Parked]** deliberately deferred.

---

## 1. Objective

Direct electrical stimulation injects a large, stereotyped transient into every iEEG channel
on every pulse. This pipeline removes that artifact while **preserving the brain signal in the
inter-pulse intervals**, so that a stimulated recording can be analyzed downstream *exactly
like a no-stim recording* — same reference, same modules, no special handling.

Concretely, at 50 Hz stimulation each pulse occupies one ~20 ms inter-pulse window; the first
~0.7 ms is a saturated **direct artifact**, and the rest is usable brain signal riding on a
decaying **secondary artifact** (post-pulse rebound). The valuable data is the between-pulse
signal *inside* the train, not just the post-train period.

**Deliverable:** a **bipolar re-referenced** cleaned signal, written back as a RAVE reference
so downstream modules load it as an ordinary re-referenced subject.

---

## 2. Two artifacts, two removal mechanisms

| Artifact | Where | Removal |
|---|---|---|
| **Direct** (pulse saturation, rails ±full-scale on *all* channels) | first `artifact_blank_width` samples of each pulse window | **blank → interpolate** (moving average, then nearest for edges). The pulse instant is a total loss on every channel; we interpolate across it. |
| **Secondary** (post-pulse rebound, varies with distance from stim site) | remainder of the inter-pulse window | **far channels:** bipolar re-reference alone. **near channels:** bipolar re-reference **+** per-pulse template subtraction. |

The user decides which channels are "near" (still need template subtraction after bipolar) by
inspecting the Welch periodogram — residual energy at the stim frequency and its harmonics
flags channels that bipolar didn't fully clean.

---

## 3. Workflow (four stages)

Analysis runs **one block at a time** (`analysis_block`), because the stim electrode and stim
parameters vary block-to-block. Loading can span many blocks; the cleaning stages operate on
the chosen block. To process another block, change `analysis_block` (+ its stim settings) and
re-run.

### Stage 1 — Load raw voltage  **[Built]**
Load unreferenced, un-notched, non-epoched voltage for the chosen contacts
(`loaded_electrodes`, blank = all LFP) across chosen blocks (`loaded_blocks`, blank = all) via
`prepare_subject_raw_voltage_with_blocks`. The timing channel is fetched on demand
(`load_stim_channel`).

### Stage 2 — Pulse detection
Recover one onset per pulse. **Two sources, in priority order:**

1. **Events channel (preferred)** **[Built]** — one of the subject's Auxiliary channels
   carries a clean square wave whose rising/falling edges mark train **onset/offset**. Detect
   train boundaries from the edges, then lay `stim_frequency × stim_train_duration` evenly
   spaced onsets within each train (`detect_pulses_from_events` → `detect_pulses_from_trigger`,
   the MATLAB `linspace` method), after an auto (bimodal) threshold. This is the robust source
   and matches the prototype.
   - **Auto-detected by shape**, **user-editable** via `event_channel`. RAVE drops the aux
     channels' original names to `NoLabel`, so `auto_detect_event_channel` identifies the
     square wave by waveform: among the Auxiliary channels, the one with almost no samples at
     intermediate levels ("squareness") and a plausible train-edge count. For PAV073 this
     resolves to **electrode 259** (46 trains → 1150 pulses in BLOCK031, onsets matching the
     `stimpulse_*` epoch tables to the millisecond). The three aux channels are 257–259; 258
     is a noisy analog line, 257 is not square.
   - This makes `stim_train_duration` **load-bearing** (it sets the pulse count per train), so
     it is *not* dead under this design.

2. **Stim electrode threshold (fallback)** **[Built]** — when no Events channel is available,
   threshold the stim electrode's own saturating signal. It rails in *both* directions and
   each biphasic pulse crosses threshold several times, so we threshold the **absolute value**
   and coalesce with a **refractory window** (0.8 × inter-pulse interval) to get one onset per
   pulse (`detect_pulses_from_stim_channel`). Verified: 1082 onsets at a clean 599-sample
   (50 Hz) spacing on PAV073 / BLOCK031, `stim_threshold = 3000`.

Onsets are detected once per block and shared by every channel.

### Stage 3 — Bipolar re-reference  **[Built]**
Subtract adjacent within-shaft contacts (`anode − cathode`); shared secondary artifact and
common-mode noise cancel, local brain signal survives. Rules:
- **Within a shaft only** — never pair across probes. Shaft = electrode `LabelPrefix`, else
  `gsub("[0-9]+$","",Label)`, else contiguous electrode-number runs when labels are absent
  (as on PAV073).
- **Skip the stim contact(s)** — pair only neighbours separated *solely* by stim electrodes
  (monopolar stim: skip one, e.g. stim 38 → bipolar `37-39`; **bipolar stim [Parked]:** skip
  both). A gap containing any non-stim contact is *not* bridged.

### Stage 4 — Template subtraction  **[Built]**
For each bipolar channel that still needs it:
1. **Snip** one inter-pulse window per pulse at the shared onsets.
2. **Align** by the local min/max within a search window. The window brackets the
   secondary-artifact landmark; polarity (trough vs. crest) is chosen by larger mean
   magnitude; each onset shifts by `ix − ix[1]` so pulses superimpose.
   - **[Designed]** the search window should be a **draggable selector on the snippet plot**
     that sets `align_search_start:align_search_end` — the author places it over the rebound
     peak and watches the alignment/template update. Today those are fixed numeric settings.
3. **Blank** the direct-artifact rows (`artifact_blank_width`) + the seam sample → `NA`.
   *(Separate control from the alignment window.)*
4. **Profile / cluster** — blind PCA + k-means (`profile_pulses`, `n_clusters`). Kept blind by
   design; it should discover the **sharp first-pulse onset transient** (first 1–3 pulses of a
   train are far more saturated) as its own cluster. Generalizable interface so
   `ravetools::bpc` or other methods can slot in later. `n_clusters = 1` ≡ the MATLAB single
   global template.
5. **Template** per cluster = demeaned (`detrend(·,0)`) average over the non-blanked rows.
6. **Subtract** each pulse's cluster template, **write back** into the continuous trace, then
   **gap-fill** the blanked regions (moving average `gap_fill_window`, then nearest).

### Export  **[Designed]**
Write the cleaned bipolar result back as a **RAVE reference** so downstream modules select it
at load time and receive clean data — no stim-specific handling anywhere downstream. Today the
pipeline writes cleaned filearrays under `data/cleaned-voltage/`; the reference-export path is
not yet built.

---

## 4. Key design decisions (from the review)

- **Output is bipolar**, not monopolar. Bipolar is the deliverable, not just a pre-step.
- **Rescue between-pulse signal**, not only post-train. The inter-pulse interval is the target.
- **Blind clustering**, trusting it to separate the onset transient; non-stationarity is
  mostly a sharp onset transient, not slow drift.
- **Events-first timing**, stim-electrode threshold only as fallback.
- **One block at a time**; stim electrode + parameters are per-block (author-supplied / stim
  log), with the Events channel confirming train timing.
- **Monopolar stim today**, bipolar stim later (skip both contacts).

---

## 5. Settings (`settings.yaml`)

Loading: `project_name`, `subject_code`, `loaded_electrodes`, `loaded_blocks`.
Analysis (per block): `analysis_block`, `analysis_electrodes`, `stim_electrode`.
Detection: `event_channel` (**[Built]**; `~` = auto-detect the square-wave aux channel,
editable), `stim_threshold` (fallback only), `stim_frequency`, `stim_train_duration`,
`pulse_duration`, `snip_window`.
Alignment/template: `align_search_start`, `align_search_end`, `artifact_blank_width`,
`template_window_pre`, `n_clusters`, `pca_n_components`.
Gap fill / export: `gap_fill_window`, `export_name`.

Every core parameter lives in `settings.yaml` so `targets` rebuilds only the affected subtree
when one changes. Cosmetic plot options stay inline in the diagnostic chunks.

---

## 6. Pipeline targets (data flow)

`subject → {loaded_electrode_clean, loaded_block_clean, analysis_electrode_clean} → repository
→ loaded_signals`; `repository → pulse_info`; `{subject, analysis_electrode_clean,
loaded_electrode_clean} → bipolar_pairs → bipolar_signals`; `{bipolar_signals, pulse_info} →
snippet_list → aligned_pulse_list → template_list → cleaned_signals`.

13 computed `{rave}` targets. Runtime outputs (`data/`, the `shared/` targets store) are
git-ignored. Core algorithm lives in `R/shared-signal_processing.R`, plotting in
`R/shared-plots.R`.

---

## 7. Mathematical fidelity to the MATLAB prototype

The signal-processing math is a faithful port of `tmp/artifact_rej.m`: snip window
`round(fs/stim_frequency)`; min/max alignment with `shift = ix − ix[1]`; blank first
`artifact_blank_width` + seam; template `detrend(mean, 0)`; write-back; `fillmissing` movmean
→ nearest. Deliberate departures (all standard, non-goofy): abs-value + refractory detection
for the stim-electrode fallback; per-cluster templates behind a pluggable interface;
within-shaft stim-aware bipolar pairing; `ravetools::pwelch` diagnostics.

---

## 8. Open / parked items

- **[Resolved]** Events channel identified by **shape** (`auto_detect_event_channel`) rather
  than the lost Blackrock name; wired as the primary detector with the stim-electrode fallback.
  The `stimpulse_*` epoch tables (train onsets, produced upstream by `stimpulse_finder`) are a
  *third* possible source not yet used — worth considering if epochs are always present.
- **[Designed, not built]** Draggable alignment-window selector on the snippet plot (Shiny).
- **[Designed, not built]** Reference-based export so downstream loads cleaned data as no-stim.
- **[Parked]** Bipolar-stim support (skip both stim contacts in pairing).
- **[Parked]** Task-locking safety: template subtraction removes anything time-locked to the
  stim pulse. If stimulation is ever delivered at a fixed latency relative to the McGurk
  stimulus, the task-evoked response would be partially removed. Out of scope for the
  artifact-removal stage; revisit before analyzing stimulus-evoked responses during stim.
- **[Watch]** With only the first 1–3 pulses/train as onset-transient outliers, blind k-means
  may fold them into the bulk; may need higher `k` or weighting when tuning.

---

## 9. Status summary

Built and verified end-to-end: the four stages with **Events-channel-first detection** (auto
channel 259 → 1150 pulses for PAV073 / BLOCK031) and the stim-electrode fallback, knitting to
HTML for `McGurkStim / PAV073`, stim electrode 38, with per-section documentation and all ten
diagnostic plots. Still designed-not-built: the alignment-window UI and reference-based export.
The Shiny `module_*.R` / `report-stim_removal.Rmd` still reference the older block-keyed target
shape and need realignment to the per-channel structure.
