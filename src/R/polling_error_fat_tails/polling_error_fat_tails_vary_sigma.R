## Purpose
# Fit polling error models with sigma as parameter
## Libraries
library(boot)
library(cmdstanr)
library(tidyverse)
library(loo)
## Load data
df <- read_csv("dta/polls_pres_dataset_00_20.csv")
###############################################################################
## Models with sigma allowed to vary
m <- file.path("src/stan/polling_error_fat_tails",
               "polling_error_fat_tails_student_t_sigma.stan")
mod <- cmdstan_model(m)
state_abb <- df %>%
  pull(state) %>%
  unique() %>%
  sort()
df <- df %>%
  group_by(state, electionDate) %>%
  mutate(i = cur_group_id(),
         s = match(state, state_abb)) %>%
  ungroup() %>%
  arrange(year) %>%
  group_by(year) %>%
  mutate(t = cur_group_id(),
         outcome = finalTwoPartyVSDemocratic / 100,
         n = floor((republican + democratic)/100 * numberOfRespondents),
         y = floor(democratic/100 * numberOfRespondents)) %>%
  left_join(data.frame(x = 1:300,
                       t = sort(rep(1:6, 50)),
                       s = rep(1:50, 6)))

## Loop
loo_list <- list()
for (i in seq(2, 30, 2)){
  print(i)
  data_list <- list(
    N = nrow(df),
    T = df %>% pull(t) %>% max(),
    S = df %>% pull(s) %>% max(),
    x = df %>% pull(x),
    y = df %>% pull(y),
    n = df %>% pull(n),
    outcome = df %>% pull(outcome),
    nu = i
  )
  fit <- mod$sample(
    data = data_list,
    seed = 123,
    chains = 4,
    parallel_chains = 4,
    refresh = 0
  )
  loo_list[[paste0("nu", i)]] <- fit$loo()

}
## Normal model
m_normal <- file.path("src/stan/polling_error_fat_tails",
                      "polling_error_fat_tails_normal_sigma.stan")
mod_normal <- cmdstan_model(m_normal)
data_list <- list(
  N = nrow(df),
  T = df %>% pull(t) %>% max(),
  S = df %>% pull(s) %>% max(),
  x = df %>% pull(x),
  y = df %>% pull(y),
  n = df %>% pull(n),
  outcome = df %>% pull(outcome)
)
fit_normal <- mod_normal$sample(
  data = data_list,
  seed = 123,
  chains = 4,
  parallel_chains = 4,
  refresh = 0
)
loo_list[["normal"]] <- fit_normal$loo()
## Compare all
weights_sigma <- as.matrix(loo_model_weights(loo_list, method = "pseudobma"))
weight_frame_sigma <- data.frame(
  model_name = rownames(weights_sigma),
  weight = weights_sigma
) %>%
  mutate(nu = as.integer(str_remove(model_name, "[^\\d]+")))
write_rds(weight_frame_sigma, "output/weight_frame_sigma.Rds")

