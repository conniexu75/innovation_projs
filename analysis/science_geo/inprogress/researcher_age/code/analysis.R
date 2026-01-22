library(tidyverse)
library(ggplot2)
library(haven)

data <- read_dta("../temp/age_prod_year.dta")
ggplot(data, aes(x = pub_age, y = impact_affl_wt, size = athr_cnt)) +
    geom_point(alpha = 0.6) +  # Adjust point transparency with alpha
    scale_size_continuous(range = c(1, 10)) + # Adjust the range for the size of the points as needed
    labs(title = "Weighted Scatter Plot of Age vs. Productivity",
        x = "Age",
        y = "Average Productivity",
        size = "Number of Authors") +
     theme_minimal() # Using a minimal theme for aesthetics
ggsave("../output/test.pdf")

