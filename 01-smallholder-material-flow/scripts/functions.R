# General functions
sm <- function(x) sum(x, na.rm = TRUE)
rd <- function(df) df %>% dplyr::mutate_if(is.numeric, round, 1)
md <- function(x) median(x, na.rm=TRUE)
mn <- function(x) mean(x, na.rm=TRUE)

# Units
sct <- function(x) x/1000 # scale to tonne
scm <- function(x) x/1000000 # scale million (mostly for population)
sc_mt <- function(x) x/1000000000 # scale to million metric ton
tokt <- 1000000
mio <- 1000000
ht <- 100000
tt <- 10000
t <- 1000

library(ggthemes)

theme_thesis <- function(
    base_size = 11, 
    base_family = "", 
    x_angle = 45, 
    caption_size = 8, 
    caption_face = "italic", 
    caption_hjust = 0, 
    legend_pos = "none",
    colour_type = "tableau10",             # Now tableau10 is the default
    custom_colours = NULL,              
    n_colours = NULL,                   
    continuous_palette = "viridis"      
) {
  # Build base theme
  thesis_theme <- theme_minimal(base_size = base_size, base_family = base_family) +
    theme(
      axis.text.x = element_text(angle = x_angle, hjust = 1),
      axis.title.x = element_text(margin = margin(t = 10)),
      axis.title.y = element_text(margin = margin(r = 10)),
      legend.position = legend_pos,
      # plot.caption.position = "panel",
      # plot.caption = element_text(
      #   hjust = caption_hjust, 
      #   face = caption_face, 
      #   size = caption_size
      # ),
      plot.title = element_text(face = "bold", size = rel(1.2)),
      plot.subtitle = element_text(size = rel(1)),
      strip.text = element_text(face = "bold"),
      plot.caption.position = "panel",
      plot.caption = element_text(
        hjust = 0,                     # left align
        face = "italic",                # italic font
        size = 8                        # size 8
      )
    )
  
  # Choose color/fill scales (only add if explicitly specified)
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
# continious
# ggplot(mydata, aes(x, y, color = value, fill = value)) +
#   geom_bar(stat = "identity") +
#   theme_thesis(colour_type = "continuous", continuous_palette = "magma")
# # two custom
# ggplot(mydata, aes(x, y, color = group, fill = group)) +
#   geom_bar(stat = "identity") +
#   theme_thesis(colour_type = "custom", custom_colours = c("red", "blue"))
# # force tableau 20
# ggplot(mydata, aes(x, y, color = group, fill = group)) +
#   geom_bar(stat = "identity") +
#   theme_thesis(colour_type = "tableau20")


# kbltbl <- function(df){
#   df %>% 
#     kableExtra::kable_styling(
#       position = "center",
#       latex_options = c("striped", "repeat_header")) 
# }

kbltbl <- function(
    df,
    full_width = FALSE,
    font_size = 10,
    position = "center",
    stripe_color = "#F2F2F2",
    latex_options = c("striped", "repeat_header"),
    align = NULL,
    caption = NULL,
    booktabs = TRUE,
    escape = TRUE,
    col_names = NULL,
    col_widths = NULL,
    ... # Pass extra args to kbl, such as longtable = TRUE
) {
  # Sanitize potentially NA arguments
  if (is.null(col_names) || (length(col_names) == 1 && is.na(col_names))) col_names <- NULL
  if (is.null(col_widths) || (length(col_widths) == 1 && is.na(col_widths))) col_widths <- NULL
  if (is.null(caption) || (length(caption) == 1 && is.na(caption))) caption <- NULL
  
  kbl <- kableExtra::kbl(
    df,
    align = align,
    caption = caption,
    booktabs = booktabs,
    escape = escape,
    col.names = col_names,
    ... # allows longtable = TRUE or other kbl args
  )
  
  # Apply column widths if provided
  if (!is.null(col_widths)) {
    for (i in seq_along(col_widths)) {
      kbl <- kableExtra::column_spec(kbl, i, width = col_widths[i])
    }
  }
  kableExtra::kable_styling(
    kbl,
    full_width = full_width,
    font_size = font_size,
    position = position,
    stripe_color = stripe_color,
    latex_options = latex_options
  )
}

clear.labels <- function(x) {
  if(is.list(x)) {
    for(i in seq_along(x)) {
      class(x[[i]]) <- setdiff(class(x[[i]]), 'labelled') 
      attr(x[[i]],"label") <- NULL
    } 
  } else {
    class(x) <- setdiff(class(x), "labelled")
    attr(x, "label") <- NULL
  }
  return(x)
}  

## Chapters 3-5----
calc <- function(df) df[, lapply(.SD, sm), .SDcols=is.numeric, by=.(type)] # change function and grouping as required; for 3c this could stay item; use groupsgroups for other aggregation levels
# col sum
cl <- function(df) df[, lapply(.SD, sm), .SDcols=is.numeric] # change function as required

## Chapter 3----
rm_ex <- function(df){
  setDT(df)
  df[!excl_3a, on = .(y4_hhid)]
}

weighting <- read_csv("data/c3/weighting.csv") 

weigh <- function(df){
  df %>% 
    right_join(weighting, by = "y4_hhid") %>% # only keep households listed in weighting (i.e., those included)
    mutate_if(is.numeric, ~replace(., is.na(.), 0)) %>%
    dplyr::select(!c(clusterid)) 
}

mfafun <- function(list){
  crops <- list$crops %>% setDT()
  
  # mfa calculations
  
  cl <- function(df) df[, lapply(.SD, sm), .SDcols=is.numeric] # change function as required
  
  c1 <- calc(crops)
  c2 <- cl(crops)
  
  # Prepare the second flow: harvest onward
  # Ensure `c1` is defined; for now assuming it's another processed table similar to `processed_crops`
  first_flow <- c1[, .(
    source = type,
    consumed,
    sold,
    transfer = payment + gifts,
    losses,
    stored,
    feed,
    processing,
    missing
  )]
  
  # Reshape the second flow data from wide to long format
  first <- melt(
    first_flow,
    id.vars = "source",
    measure.vars = c("consumed", "sold", "transfer", "losses", "stored", "feed", "processing", "missing"),
    variable.name = "target",
    variable.factor = FALSE
  )
  
  # third flow: processing
  second_flow <- c2[,.
                    (source = "processing", 
                      sold = prodsold, 
                      consumed = prodconsumed, 
                      waste = waste)]
  
  second <- melt(
    second_flow,
    id.vars = "source",
    measure.vars = c("sold", "consumed", "waste"),
    variable.name = "target",
    variable.factor = FALSE) # sum of which should be "produced"
  
  second2 <- c2[,.(value = seed)]
  second2[, `:=` (source = "stored",
                  target = "seed")]
  
  
  data <- rbind(first, second, second2)
  
  ### MEAT----
  # extract from list
  meat <- list$meat %>% setDT()
  
  # collapse and calculate
  m1 <- calc(meat)
  m2 <- cl(meat)
  
  feed <- melt(m1, id.vars = "type",
               measure.vars = c("feed", "grazed"),
               variable.name = "source",
               variable.factor = FALSE)
  setnames(feed, old = "type", new = "target")
  
  # first flow types to slaughter
  first <- m1[,.(source = type, value = slaughtered)]
  first[, target := "slaughtered" ]
  
  # second flow from slaughter
  second_flow <- m2[,.(source = "slaughtered", 
                       sold, 
                       inedible,
                       meat,
                       offal,
                       hides)]
  
  second <- melt(
    second_flow,
    id.vars = "source",
    measure.vars = c("sold", "inedible", "meat", "offal", "hides"),
    variable.name = "target",
    variable.factor = FALSE) # sum of which should be "produced"
  
  # last flow from hides
  third <- m2[,.(source = "meat", target = "consumed", value = pluck(m2$meat))]
  third2 <- m2[,.(source = "offal", target = "consumed", value = pluck(m2$offal))]
  
  third3 <- m2[,.(source = "hides", target = "waste", value = pluck(m2$waste))]
  
  third4 <- m2[,.(source = "hides", target = "processing", value = pluck(m2$prodproduced))] # this should be processing
  fourth <- m2[,.(source = "processing", target = "sold", value = pluck(m2$prodsold))]
  fourth2 <- m2[,.(source = "processing", target = "consumed", value = pluck(m2$hides_cons))]
  
  data2 <- rbind(feed, first, second, third, third2, third3, third4, fourth, fourth2)
  
  ### Animal products----
  ap <- list$ap
  
  ap1 <- ap[, lapply(.SD, sm), .SDcols=is.numeric, by=.(type, product)]
  ap2 <- ap[, lapply(.SD, sm), .SDcols=is.numeric, by=.(product)]
  ap3 <- cl(ap)
  
  # feed flow to total eggs produced (not necessary to have the chicken as middle step)
  feed <- melt(ap1, id.vars = "type",
               measure.vars = c("feed", "grazed"),
               variable.name = "source",
               variable.factor = FALSE)
  setnames(feed, old = "type", new = "target")
  
  # first flow eggs produced
  first <- ap1[,.(source = type, value = produced, target = product)]
  
  second_flow <- ap2[,.(source = product, 
                        consumed,
                        sold,
                        missing,
                        processing)]
  second <- melt(
    second_flow,
    id.vars = "source",
    measure.vars = c("consumed","sold", "missing", "processing"),
    variable.name = "target",
    variable.factor = FALSE)
  
  third <- ap3[,.(source = "processing", value = prodsold, target = "sold")]
  
  data3 <- rbind(feed, first, second, third)
  
  #### MERGE-----
  datamfa <- rbind(data, data2, data3)
}

# sankey <- function(data){
#   nodes <- data.frame(name=c(as.character(data$source), as.character(data$target)) %>% unique())
#   
#   data$IDsource <- match(data$source, nodes$name)-1
#   data$IDtarget <- match(data$target, nodes$name)-1
#   
#   data <- data %>%
#     mutate_if(is.character, str_to_sentence)
#   
#   nb.cols <- nrow(nodes)
#   mycolors <- colorRampPalette(brewer.pal(11, "PiYG"))(nb.cols)
#   
#   
#   fig <- plot_ly(
#     type = "sankey",
#     orientation = "h",
#     
#     node = list(
#       label = nodes$name,
#       color = mycolors,
#       pad = 15,
#       thickness = 20,
#       line = list(
#         color = "black",
#         width = 0.5
#       )
#     ),
#     
#     link = list(
#       source = data$IDsource,
#       target = data$IDtarget,
#       value =  data$value,
#       color = "light grey"
#       
#     )
#   )
#   # fig <- fig %>% layout(
#   #   title = "Material Flow LSMS-ISA TZA wave 4",
#   #   font = list(
#   #     size = 10
#   #   )
#   #)
#   fig
# }
# Sankey Diagram Function with Values Displayed
sankey <- function(data, 
                   title = " ", 
                   subtitle = NULL,
                   color_palette = "Spectral", 
                   orientation = "h",
                   node_font_size = 12,
                   label_padding = 15,
                   node_thickness = 20,
                   node_line_color = "black",
                   node_line_width = 0.5) {
  library(dplyr)
  library(plotly)
  library(RColorBrewer)
  
  # Ensure required columns are present
  required_columns <- c("source", "target", "value")
  if (!all(required_columns %in% colnames(data))) {
    stop("Input data must contain the columns: 'source', 'target', and 'value'.")
  }
  
  # Create nodes data frame
  nodes <- data.frame(name = unique(c(as.character(data$source), as.character(data$target))))
  
  # Map source and target to node IDs
  data <- data %>%
    mutate(
      IDsource = match(source, nodes$name) - 1,
      IDtarget = match(target, nodes$name) - 1
    )
  
  # Ensure proper capitalization for node names
  nodes$name <- stringr::str_to_sentence(nodes$name)
  
  # Generate colors for nodes
  nb_cols <- nrow(nodes)
  my_colors <- colorRampPalette(brewer.pal(min(11, nb_cols), color_palette))(nb_cols)
  
  # Create the Sankey plot
  fig <- plot_ly(
    type = "sankey",
    orientation = orientation,
    
    node = list(
      label = nodes$name,
      color = my_colors,
      pad = label_padding,
      thickness = node_thickness,
      line = list(
        color = node_line_color,
        width = node_line_width
      ),
      font = list(
        size = node_font_size
      )
    ),
    
    link = list(
      source = data$IDsource,
      target = data$IDtarget,
      value = data$value,
      color = "lightgrey",
      # Display values as hover text on the links
      hoverinfo = "text",
      text = paste("Value: ", data$value)
    )
  )
  
  # Add title, subtitle, and layout styling
  fig <- fig %>%
    layout(
      title = list(
        text = paste0("<b>", title, "</b>", if (!is.null(subtitle)) paste0("<br><sub>", subtitle, "</sub>") else ""),
        font = list(size = 16),
        xref = "paper",
        x = 0.5
      ),
      font = list(size = 10),
      margin = list(t = 50, b = 30, l = 50, r = 50)
    )
  
  return(fig)
}
## Chapter 4----

name_months <- function(df){
  df %>% 
    mutate(
      month = fcase(
        month == 1, "January",
        month == 2, "February",
        month == 3, "March",
        month == 4, "April",
        month == 5, "May",
        month == 6, "June",
        month == 7, "July",
        month == 8, "August",
        month == 9, "September",
        month == 10, "October",
        month == 11, "November",
        month == 12, "December"),
      month = factor(month, 
                     levels = c("January", "February", "March", "April", "May", "June",
                                "July", "August", "September", "October", "November", "December")))
}

calc.diffs <- function(df, fun){ # add element for function
  df %>% 
    # summarise(across(c(tot.crude:bootTt), ~ fun(.x))) %>% 
    mutate(
      mean = (tot.spat + tot.temp + bootSt + bootTt)/4,
      diffccS = tot.crude - tot.spat, # calculate difference between proposed method and given data
      diffccT = tot.crude - tot.temp,
      diffcbS = tot.crude - bootSt,
      diffcbT = tot.crude - bootTt)
} 

calc.diff.stats <- function(df){
  df %>% 
    summarise(
      across(c(diffccS:diffcbT), ~ sd(.x, na.rm=T), .names = "sd.{.col}"), # sd first as following alters diff vars
      across(c(diffccS:diffcbT), ~ mn(.x)),
      n = n()
    ) %>% 
    mutate(
      se.ccS = sd.diffccS/sqrt(n),
      se.ccT = sd.diffccT/sqrt(n),
      se.cbS = sd.diffcbS/sqrt(n),
      se.cbT = sd.diffcbT/sqrt(n),
      # confidence interval - repeat for all
      lower.ci.ccS = diffccS - qt(1 - (0.05/2), n -1) * se.ccS,
      upper.ci.ccS = diffccS + qt(1 - (0.05/2), n -1) * se.ccS,
      lower.ci.ccT = diffccT - qt(1 - (0.05/2), n -1) * se.ccT,
      upper.ci.ccT = diffccT + qt(1 - (0.05/2), n -1) * se.ccT,
      lower.ci.cbS = diffcbS - qt(1 - (0.05/2), n -1) * se.cbS,
      upper.ci.cbS = diffcbS + qt(1 - (0.05/2), n -1) * se.cbS,
      lower.ci.cbT = diffcbT - qt(1 - (0.05/2), n -1) * se.cbT,
      upper.ci.cbT = diffcbT + qt(1 - (0.05/2), n -1) * se.cbT
    )
}

## Chapter 5----