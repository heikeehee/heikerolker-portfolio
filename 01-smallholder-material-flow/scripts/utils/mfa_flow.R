# =============================================================================
# utils/mfa_flow.R
# PURPOSE: MFA flow construction and Sankey visualisation utilities
# SOURCE:  mfafun() and sankey() extracted from archive — original logic preserved
# ADDED:   household-level and type-level wrappers for per-household analysis
#          and project 03 clustering
# =============================================================================
#
# Dependencies (loaded via packages.R / functions.R before sourcing this file):
#   data.table, dplyr, purrr, plotly, RColorBrewer, stringr
#
# Helper functions used inside mfafun() — must be available in calling environment:
#   sm()   — sum(x, na.rm = TRUE)              defined in functions.R
#   calc() — grouped column sum by type        defined in functions.R
#   cl()   — ungrouped column sum (all numeric) defined in functions.R
# =============================================================================


# Full MFA calculation: takes a named list with elements $crops, $meat, $ap
# Returns a long-format data frame of source-target-value flows for Sankey
mfafun <- function(list) {

  crops <- list$crops %>% setDT()

  c1 <- calc(crops)
  c2 <- cl(crops)

  first_flow <- c1[, .(
    source     = type,
    consumed,
    sold,
    transfer   = payment + gifts,
    losses,
    stored,
    feed,
    processing,
    missing
  )]

  first <- melt(
    first_flow,
    id.vars       = "source",
    measure.vars  = c("consumed", "sold", "transfer", "losses",
                      "stored", "feed", "processing", "missing"),
    variable.name   = "target",
    variable.factor = FALSE
  )

  second_flow <- c2[, .(
    source   = "processing",
    sold     = prodsold,
    consumed = prodconsumed,
    waste    = waste
  )]

  second <- melt(
    second_flow,
    id.vars       = "source",
    measure.vars  = c("sold", "consumed", "waste"),
    variable.name   = "target",
    variable.factor = FALSE
  )

  second2 <- c2[, .(value = seed)]
  second2[, `:=` (source = "stored", target = "seed")]

  data <- rbind(first, second, second2)


  ### MEAT ----

  meat <- list$meat %>% setDT()

  m1 <- calc(meat)
  m2 <- cl(meat)

  feed <- melt(
    m1,
    id.vars       = "type",
    measure.vars  = c("feed", "grazed"),
    variable.name   = "source",
    variable.factor = FALSE
  )
  setnames(feed, old = "type", new = "target")

  first <- m1[, .(source = type, value = slaughtered)]
  first[, target := "slaughtered"]

  second_flow <- m2[, .(
    source   = "slaughtered",
    sold,
    inedible,
    meat,
    offal,
    hides
  )]

  second <- melt(
    second_flow,
    id.vars       = "source",
    measure.vars  = c("sold", "inedible", "meat", "offal", "hides"),
    variable.name   = "target",
    variable.factor = FALSE
  )

  # pluck() extracts a scalar from a single-row data.table.
  # m2 is always single-row here — cl() collapses to one row before this point.
  # If the pipeline upstream of cl() changes, review these lines.
  third   <- m2[, .(source = "meat",       target = "consumed",   value = pluck(m2$meat))]
  third2  <- m2[, .(source = "offal",      target = "consumed",   value = pluck(m2$offal))]
  third3  <- m2[, .(source = "hides",      target = "waste",      value = pluck(m2$waste))]
  third4  <- m2[, .(source = "hides",      target = "processing", value = pluck(m2$prodproduced))]
  fourth  <- m2[, .(source = "processing", target = "sold",       value = pluck(m2$prodsold))]
  fourth2 <- m2[, .(source = "processing", target = "consumed",   value = pluck(m2$hides_cons))]

  data2 <- rbind(feed, first, second, third, third2, third3, third4, fourth, fourth2)


  ### Animal products ----

  ap  <- list$ap
  ap1 <- ap[, lapply(.SD, sm), .SDcols = is.numeric, by = .(type, product)]
  ap2 <- ap[, lapply(.SD, sm), .SDcols = is.numeric, by = .(product)]
  ap3 <- cl(ap)

  feed <- melt(
    ap1,
    id.vars       = "type",
    measure.vars  = c("feed", "grazed"),
    variable.name   = "source",
    variable.factor = FALSE
  )
  setnames(feed, old = "type", new = "target")

  first <- ap1[, .(source = type, value = produced, target = product)]

  second_flow <- ap2[, .(
    source     = product,
    consumed,
    sold,
    missing,
    processing
  )]

  second <- melt(
    second_flow,
    id.vars       = "source",
    measure.vars  = c("consumed", "sold", "missing", "processing"),
    variable.name   = "target",
    variable.factor = FALSE
  )

  third <- ap3[, .(source = "processing", value = prodsold, target = "sold")]

  data3 <- rbind(feed, first, second, third)


  ### Merge all flows ----
  datamfa <- rbind(data, data2, data3)
}

# =============================================================================
# 🚩 FLAG [UNIT]: feed_total = feed_crops_kg_fresh + feed_liveweight_kg_DM
# Units are not comparable — fresh weight ≠ dry matter.
# Correction requires per-crop DM conversion factors applied to crop-level feed quantities.
# LSMS-ISA does not record which crops were fed — conversion unresolvable for most households.
# Decision: sum as-is. Sankey flow proportions remain informative; absolute values are not kg DM.
# Do not cite absolute feed totals as dry matter equivalents.
# [partial correction attempted in archive/03_Animals.Rmd (liveweight-derived feed in kg DM) —
#  crop-level fresh weight feed not converted — not carried forward]
# Backlog B08 — revisit if crop-level feed recording improves in future survey waves.
# =============================================================================


# Generates an interactive Sankey diagram from a source-target-value data frame.
# Colour palette, orientation and node styling are parameterised.
# All library dependencies must be loaded via packages.R before calling.

sankey <- function(
    data,
    title           = " ",
    subtitle        = NULL,
    color_palette   = "Spectral",
    orientation     = "h",
    node_font_size  = 12,
    label_padding   = 15,
    node_thickness  = 20,
    node_line_color = "black",
    node_line_width = 0.5
) {
  required_columns <- c("source", "target", "value")
  if (!all(required_columns %in% colnames(data))) {
    stop("Input data must contain columns: 'source', 'target', 'value'.")
  }

  nodes <- data.frame(
    name = unique(c(as.character(data$source), as.character(data$target)))
  )

  data <- data %>%
    mutate(
      IDsource = match(source, nodes$name) - 1,
      IDtarget = match(target, nodes$name) - 1
    )

  nodes$name <- stringr::str_to_sentence(nodes$name)

  nb_cols   <- nrow(nodes)
  my_colors <- colorRampPalette(RColorBrewer::brewer.pal(min(11, nb_cols), color_palette))(nb_cols)

  fig <- plot_ly(
    type        = "sankey",
    orientation = orientation,
    node = list(
      label     = nodes$name,
      color     = my_colors,
      pad       = label_padding,
      thickness = node_thickness,
      line      = list(color = node_line_color, width = node_line_width),
      font      = list(size = node_font_size)
    ),
    link = list(
      source    = data$IDsource,
      target    = data$IDtarget,
      value     = data$value,
      color     = "lightgrey",
      hoverinfo = "text",
      text      = paste("Value:", data$value)
    )
  )

  fig <- fig %>%
    layout(
      title = list(
        text = paste0(
          "<b>", title, "</b>",
          if (!is.null(subtitle)) paste0("<br><sub>", subtitle, "</sub>") else ""
        ),
        font = list(size = 16),
        xref = "paper",
        x    = 0.5
      ),
      font   = list(size = 10),
      margin = list(t = 50, b = 30, l = 50, r = 50)
    )

  return(fig)
}


# =============================================================================
# WRAPPER: single household flow
# Returns mfafun output filtered to one y4_hhid
# Use for: household-level Sankey, project 03 individual profiles
# =============================================================================

mfa_flow_hh <- function(data_list, hhid) {
  hh_list <- lapply(data_list, function(df) {
    if (is.data.table(df)) df[y4_hhid == hhid]
    else filter(df, y4_hhid == hhid)
  })
  mfafun(hh_list)
}


# =============================================================================
# WRAPPER: population-level flow collapsed to type
# Sums across all households before running mfafun
# Use for: population Sankey in 09_outputs.R
# =============================================================================

mfa_flow_type <- function(data_list) {
  type_list <- lapply(data_list, function(df) {
    if (is.data.table(df)) {
      df[, lapply(.SD, sum, na.rm = TRUE), .SDcols = is.numeric, by = type]
    } else {
      df |> group_by(type) |>
        summarise(across(where(is.numeric), \(x) sum(x, na.rm = TRUE)), .groups = "drop")
    }
  })
  mfafun(type_list)
}


# =============================================================================
# WRAPPER: all households (returns named list of flows)
# Use for: project 03 — one flow per household for clustering input
# =============================================================================

mfa_flow_all_hh <- function(data_list) {
  hhids <- unique(data_list$crops$y4_hhid)
  flows <- purrr::map(hhids, \(id) mfa_flow_hh(data_list, id))
  purrr::set_names(flows, hhids)
}
