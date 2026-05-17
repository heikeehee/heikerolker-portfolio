
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

# Test function - unweighted
list <- list(
  crops = household_crops_complete,
  ap = household_ap_complete,
  meat = household_meat_complete
)

mfa_unweighted <- lapply(list, function(df) {
  colnames(df) <- sub("^dest_", "", colnames(df))
  df
})

saveRDS(mfa_unweighted, "data/c5/hh_level_mfa.RDS")

mfa <- mfafun(mfa_unweighted)
fwrite(mfa, "data/c3/mfa_unweighted.csv")
sankey(mfa)

# Test function - weighted

list <- list(
  crops = crops_weighted,
  ap = ap_weighted,
  meat = meat_weighted
)

list <- lapply(weighted_flows, function(df) {
  colnames(df) <- sub("^dest_", "", colnames(df))
  df
})

mfaW <- mfafun(list)


sankey(mfaW)

# Normalise flows----
df <- mfa
df[, total := sum(value), by = source] # Add total value for each source
df[, normalized := value / total]   

# Validate----
