# =============================================================================
# functions.R
# Shared functions for all chapters
#
# Package dependencies (load via packages.R before sourcing this file):
#   tidyverse, data.table, kableExtra, ggthemes, plotly, RColorBrewer,
#   stringr, purrr, dplyr
# =============================================================================


# -----------------------------------------------------------------------------
# General utility functions
# -----------------------------------------------------------------------------

sm <- function(x) sum(x, na.rm = TRUE)
rd <- function(df) df %>% dplyr::mutate_if(is.numeric, round, 1)
md <- function(x) median(x, na.rm = TRUE)
mn <- function(x) mean(x, na.rm = TRUE)


# -----------------------------------------------------------------------------
# Unit scaling
# -----------------------------------------------------------------------------

sct   <- function(x) x / 1000          # kg to tonne
scm   <- function(x) x / 1000000       # to millions
sc_mt <- function(x) x / 1000000000    # to million metric tonnes

tokt <- 1000000
mio  <- 1000000
ht   <- 100000
tt   <- 10000
kt    <- 1000


# -----------------------------------------------------------------------------
# Theme: thesis / portfolio plots
# -----------------------------------------------------------------------------

theme_thesis <- function(
    base_size          = 11,
    base_family        = "",
    x_angle            = 45,
    caption_size       = 8,
    caption_face       = "italic",
    caption_hjust      = 0,
    legend_pos         = "none",
    colour_type        = "tableau10",
    custom_colours     = NULL,
    n_colours          = NULL,
    continuous_palette = "viridis"
) {
  thesis_theme <- theme_minimal(base_size = base_size, base_family = base_family) +
    theme(
      axis.text.x           = element_text(angle = x_angle, hjust = 1),
      axis.title.x          = element_text(margin = margin(t = 10)),
      axis.title.y          = element_text(margin = margin(r = 10)),
      legend.position       = legend_pos,
      plot.title            = element_text(face = "bold", size = rel(1.2)),
      plot.subtitle         = element_text(size = rel(1)),
      strip.text            = element_text(face = "bold"),
      plot.caption.position = "panel",
      plot.caption          = element_text(hjust = 0, face = "italic", size = 8)
    )

  scale_layers <- list()

  if (!is.null(colour_type)) {
    if (colour_type == "custom" && !is.null(custom_colours)) {
      scale_layers <- list(
        scale_color_manual(values = custom_colours),
        scale_fill_manual(values = custom_colours)
      )
    } else if (colour_type == "continuous") {
      scale_layers <- list(
        scale_color_viridis_c(option = continuous_palette),
        scale_fill_viridis_c(option = continuous_palette)
      )
    } else if (colour_type == "tableau10") {
      if (!is.null(n_colours) && n_colours > 10) {
        scale_layers <- list(
          ggthemes::scale_color_tableau("Tableau 20"),
          ggthemes::scale_fill_tableau("Tableau 20")
        )
      } else {
        scale_layers <- list(
          ggthemes::scale_color_tableau("Tableau 10"),
          ggthemes::scale_fill_tableau("Tableau 10")
        )
      }
    } else if (colour_type == "tableau20") {
      scale_layers <- list(
        ggthemes::scale_color_tableau("Tableau 20"),
        ggthemes::scale_fill_tableau("Tableau 20")
      )
    }
  }

  c(list(thesis_theme), scale_layers)
}


# -----------------------------------------------------------------------------
# Table formatting
# -----------------------------------------------------------------------------

kbltbl <- function(
    df,
    full_width    = FALSE,
    font_size     = 10,
    position      = "center",
    stripe_color  = "#F2F2F2",
    latex_options = c("striped", "repeat_header"),
    align         = NULL,
    caption       = NULL,
    booktabs      = TRUE,
    escape        = TRUE,
    col_names     = NULL,
    col_widths    = NULL,
    ...
) {
  # Sanitise optional arguments — avoids downstream errors from NA defaults
  if (is.null(col_names)  || (length(col_names)  == 1 && is.na(col_names)))  col_names  <- NULL
  if (is.null(col_widths) || (length(col_widths) == 1 && is.na(col_widths))) col_widths <- NULL
  if (is.null(caption)    || (length(caption)    == 1 && is.na(caption)))    caption    <- NULL

  kbl <- kableExtra::kbl(
    df,
    align     = align,
    caption   = caption,
    booktabs  = booktabs,
    escape    = escape,
    col.names = col_names,
    ...
  )

  if (!is.null(col_widths)) {
    for (i in seq_along(col_widths)) {
      kbl <- kableExtra::column_spec(kbl, i, width = col_widths[i])
    }
  }

  kableExtra::kable_styling(
    kbl,
    full_width    = full_width,
    font_size     = font_size,
    position      = position,
    stripe_color  = stripe_color,
    latex_options = latex_options
  )
}


# -----------------------------------------------------------------------------
# Data cleaning helpers
# -----------------------------------------------------------------------------

# Strip haven labels after read_dta — required for Stata-origin LSMS data
clear.labels <- function(x) {
  if (is.list(x)) {
    for (i in seq_along(x)) {
      class(x[[i]])         <- setdiff(class(x[[i]]), "labelled")
      attr(x[[i]], "label") <- NULL
    }
  } else {
    class(x)         <- setdiff(class(x), "labelled")
    attr(x, "label") <- NULL
  }
  return(x)
}


# -----------------------------------------------------------------------------
# Chapter 3: MFA pipeline functions
# -----------------------------------------------------------------------------

# Column sum across all numeric columns (no grouping)
cl <- function(df) df[, lapply(.SD, sm), .SDcols = is.numeric]

# Grouped column sum by 'type' — adjust grouping variable as needed per call site
calc <- function(df) df[, lapply(.SD, sm), .SDcols = is.numeric, by = .(type)]

# Apply exclusion list: remove households in exclusions from df
# exclusions: data.table of household IDs to exclude (default: excl_3a from calling environment)
rm_ex <- function(df, exclusions = excl_3a) {
  setDT(df)
  df[!exclusions, on = .(y4_hhid)]
}

# Apply survey weights: right-join to weighting table, zero-fill NAs, drop clusterid
# weighting must be loaded in the calling script before calling this function — it is not
# loaded here. See 03-chap3.Rmd for the correct load: read_csv() %>% clear.labels()
weigh <- function(df) {
  df %>%
    right_join(weighting, by = "y4_hhid") %>%
    mutate_if(is.numeric, ~ replace(., is.na(.), 0)) %>%
    dplyr::select(!c(clusterid))
}

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


# -----------------------------------------------------------------------------
# Sankey diagram
# -----------------------------------------------------------------------------

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


# -----------------------------------------------------------------------------
# Chapter 4: Survey harmonisation helpers
# -----------------------------------------------------------------------------

name_months <- function(df) {
  df %>%
    mutate(
      month = fcase(
        month == 1,  "January",
        month == 2,  "February",
        month == 3,  "March",
        month == 4,  "April",
        month == 5,  "May",
        month == 6,  "June",
        month == 7,  "July",
        month == 8,  "August",
        month == 9,  "September",
        month == 10, "October",
        month == 11, "November",
        month == 12, "December"
      ),
      month = factor(month, levels = c(
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
      ))
    )
}

# NOTE (backlog): 'fun' parameter unused — remove when Chapter 4 scripts reviewed
calc.diffs <- function(df, fun) {
  df %>%
    mutate(
      mean    = (tot.spat + tot.temp + bootSt + bootTt) / 4,
      diffccS = tot.crude - tot.spat,
      diffccT = tot.crude - tot.temp,
      diffcbS = tot.crude - bootSt,
      diffcbT = tot.crude - bootTt
    )
}

calc.diff.stats <- function(df) {
  df %>%
    summarise(
      across(c(diffccS:diffcbT), ~ sd(.x, na.rm = TRUE), .names = "sd.{.col}"),
      across(c(diffccS:diffcbT), ~ mn(.x)),
      n = n()
    ) %>%
    mutate(
      se.ccS = sd.diffccS / sqrt(n),
      se.ccT = sd.diffccT / sqrt(n),
      se.cbS = sd.diffcbS / sqrt(n),
      se.cbT = sd.diffcbT / sqrt(n),
      lower.ci.ccS = diffccS - qt(1 - (0.05 / 2), n - 1) * se.ccS,
      upper.ci.ccS = diffccS + qt(1 - (0.05 / 2), n - 1) * se.ccS,
      lower.ci.ccT = diffccT - qt(1 - (0.05 / 2), n - 1) * se.ccT,
      upper.ci.ccT = diffccT + qt(1 - (0.05 / 2), n - 1) * se.ccT,
      lower.ci.cbS = diffcbS - qt(1 - (0.05 / 2), n - 1) * se.cbS,
      upper.ci.cbS = diffcbS + qt(1 - (0.05 / 2), n - 1) * se.cbS,
      lower.ci.cbT = diffcbT - qt(1 - (0.05 / 2), n - 1) * se.cbT,
      upper.ci.cbT = diffcbT + qt(1 - (0.05 / 2), n - 1) * se.cbT
    )
}


# -----------------------------------------------------------------------------
# Chapter 5
# (functions to be added as Chapter 5 scripts are reviewed)
# -----------------------------------------------------------------------------


# --- Data preparation helpers (from functions1.R) ---

# NOTE (backlog): firstfun() from functions1.R not integrated — references
# 'identifiers_ag' from calling environment rather than accepting it as an argument.
# Refactor to accept df as parameter before use. Not currently called in pipeline.

# Rename data.table columns using a named vector.
# Usage: dt_rename(dt, c(old_name = "new_name"))
dt_rename <- function(x, n) setnames(x, names(n), n)

# Standard clean-up pipeline for LSMS Stata files loaded with read_dta():
# convert to data.table, apply factor labels, lowercase factor levels,
# replace empty strings with NA, and drop 'occ' if present.
clean_up <- function(x) {
  x %>%
    setDT() %>%
    as_factor() %>%
    mutate(across(where(is.factor), tolower)) %>%
    mutate_if(is.character, ~na_if(., "")) %>%
    select(-any_of("occ"))
}

# Prepare a data frame for seasonal joining: calls clean_up() then adds a
# 'season' column.
prep <- function(x, season) {
  x %>%
    clean_up() %>%
    add_column(season = season)
}

# Replace a season-letter suffix in column names (e.g. "4b" -> "4a") so that
# short- and long-rainy data frames share identical column names before binding.
strip_colnames <- function(x, from, to) {
  names(x) <- gsub(from, to, names(x), fixed = TRUE)
  x
}

# Bind two data.tables by row, allowing mismatched columns (fill = TRUE).
bind_dt <- function(x, y) {
  rbindlist(list(x, y), fill = TRUE)
}

# Extract variable labels from a data frame into a named character vector
# suitable for re-applying with Hmisc::label() after cleaning.
prep_labs <- function(x) {
  labs <- lapply(x, attr, "label")
  unlist(labs, use.names = TRUE)
}

# Join df with a reference lookup list on 'col' to attach standardised crop
# type names. 'list' is a named parameter to match the calling convention used
# in the wrangling scripts.
clean_names <- function(df, list, col) {
  df %>% left_join(list, by = col)
}

# Re-apply variable labels from a raw (pre-cleaning) data frame to a cleaned
# data frame. Useful after clean_up() strips Stata labels.
labfix <- function(df, raw) {
  labs <- lapply(raw, attr, "label")
  labs <- unlist(labs, use.names = TRUE)
  label(df) <- as.list(labs[match(names(df), names(labs))])
  df
}

# Add a label attribute to a vector (compatible with the Hmisc label workflow).
adlab <- function(x, label) {
  attr(x, "label") <- label
  x
}

# Top-2%: returns the 99th-percentile value of x. Used as an upper outlier
# threshold in yield-gap analysis.
top2 <- function(x) quantile(x, probs = .99, na.rm = TRUE)

# NOTE (backlog): crops_list should be externalised to data/reference/crops_list.csv
# for auditability and easier maintenance outside R.
crops_list <- data.frame(
  cropid = c(
    # Cereals
    "maize", "paddy", "sorghum", "bulrush millet", "finger millet",
    "wheat", "barley",
    # Roots and tubers
    "cassava", "sweet potatoes", "irish potatoes", "yams",
    # Pulses
    "beans", "cowpeas", "groundnuts", "pigeon peas", "soybeans",
    "bambara nuts", "lentils",
    # Oil crops
    "sunflower", "sesame", "palm oil",
    # Cash crops
    "coffee", "tea", "tobacco", "cotton", "cashewnuts", "coconuts",
    "sisal", "cocoa", "vanilla", "pyrethrum",
    # Fruits and vegetables
    "banana", "plantain", "mango", "avocado", "pineapple", "passion fruit",
    "citrus", "tomatoes", "onions", "cabbage", "amaranths", "watermelon",
    # Other
    "other crops", "other vegetables", "other fruits",
    "other permanent crops", "sugar cane"
  ),
  type = c(
    # Cereals
    "cereals", "cereals", "cereals", "cereals", "cereals",
    "cereals", "cereals",
    # Roots and tubers
    "roots and tubers", "roots and tubers", "roots and tubers", "roots and tubers",
    # Pulses
    "pulses", "pulses", "pulses", "pulses", "pulses",
    "pulses", "pulses",
    # Oil crops
    "oilcrops", "oilcrops", "oilcrops",
    # Cash crops
    "cashcrops", "cashcrops", "cashcrops", "cashcrops", "cashcrops", "cashcrops",
    "cashcrops", "cashcrops", "cashcrops", "cashcrops",
    # Fruits and vegetables
    "fruits and vegetables", "fruits and vegetables", "fruits and vegetables",
    "fruits and vegetables", "fruits and vegetables", "fruits and vegetables",
    "fruits and vegetables", "fruits and vegetables", "fruits and vegetables",
    "fruits and vegetables", "fruits and vegetables", "fruits and vegetables",
    # Other
    "other crops", "fruits and vegetables", "fruits and vegetables",
    "other crops", "cashcrops"
  ),
  stringsAsFactors = FALSE
)
