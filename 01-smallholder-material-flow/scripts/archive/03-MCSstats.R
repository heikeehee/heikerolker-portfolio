# Households with most uncertainty
simulation_results_ap <- read_csv("data/c3/simulation_results_ap.csv") %>% setDT()
simulation_results_crops <- read_csv("data/c3/simulation_results_crops.csv") %>% setDT()
simulation_results_meat <- read_csv("data/c3/simulation_results_meat.csv") %>% setDT()

simulation_results <- bind_rows(simulation_results_ap, simulation_results_crops, simulation_results_meat)

fwrite(simulation_results, "data/c3/simulation_combined.csv")

# Group by household and calculate uncertainty metrics
household_uncertainty <- simulation_results[
  , .(
    mean_flow = mean(simulated_values, na.rm = TRUE),
    sd_flow = sd(simulated_values, na.rm = TRUE),
    cv_flow = sd(simulated_values, na.rm = TRUE) / mean(simulated_values, na.rm = TRUE)
  ),
  by = household_id
]

# Sort by CV (most uncertain households first)
most_uncertain_households <- household_uncertainty[order(-cv_flow)]

library(ggplot2)
ggplot(most_uncertain_households[1:10], aes(x = reorder(household_id, -cv_flow), y = cv_flow)) +
  geom_bar(stat = "identity") +
  labs(x = "Household ID", y = "Coefficient of Variation (CV)", title = "Households with Most Uncertainty") +
  theme_minimal()