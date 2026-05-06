
# mfa table
calc <- function(df) df[, lapply(.SD, sm), .SDcols=is.numeric, by=.(type)] # change function and grouping as required
# col sum
cl <- function(df) df[, lapply(.SD, sm), .SDcols=is.numeric] # change function as required

# order and bind
order <- function(df) setcolorder(df, c("source", "target", "value"))

# there shouldn't be any NAs
sm <- function(x) sum(x, na.rm=TRUE)
mn <- function(x) mean(x, na.rm=TRUE)
md <- function(x) median(x, na.rm = TRUE)

# single fun (should use singles from above)
mfafun <- function(list){
  crops <- list$crops %>% setDT() %>% ungroup()
  
  # mfa calculations
  
  cl <- function(df) df[, lapply(.SD, sm), .SDcols=is.numeric] # change function as required
  
  c1 <- calc(crops)
  c2 <- cl(crops)
  
  # Prepare the second flow: harvest onward
  # Ensure `c1` is defined; for now assuming it's another processed table similar to `processed_crops`
  first_flow <- c1[, .(
    source = c1$type,
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
  
  third <- c2[,.(source = "consumed", target = "missing", value = pluck(c2$conswaste))]
  third2 <- c2[,.(source = "consumed", target = "household", value = pluck(c2$consFprod))]
  
  
  data <- rbind(first, second, second2, third, third2)
  
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
  ap <- list$ap %>% setDT()
  
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
  
  ### CONSUMPTION
  cons <- list$cons %>% setDT()
  cons1 <- calc(cons)
  cons2 <- cl(cons)
  
  consd <- cons1[,.(source = "consumed", 
                            target = "household", 
                            value = pluck(cons1$consFprod))]
  consd2 <- cons1[,.(source = "consumed", 
                    target = "missing", 
                    value = pluck(cons1$conswaste))]
  
  #### MERGE-----
  datamfa <- rbind(data, data2, data3, consd, consd2)
}

mfa <- mfafun(list)
fwrite(mfa, "2_data/results/mfa_C4.csv")

sankey <- function(data, 
                   title = "Sankey Diagram", 
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
sankey(mfa)



