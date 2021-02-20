library(boot)
library(cmdstanr)
library(tidyverse)
library(loo)
df <- read_csv("dta/polls_pres_dataset_00_20.csv")
results <- read_csv("dta/potus_results_76_20.csv") %>%
  left_join(df %>% distinct(state), by = c("state_po" = "state"))
states_2020_ordered <- results %>%
  filter(year == 2020) %>%
  mutate(pos = dem/(dem + rep)) %>%
  arrange(pos) %>%
  pull(state_po)
results_2020 <- results %>%
  filter(year == 2020) %>%
  mutate(finalTwoPartyVSRepublican = rep/(dem + rep) * 100,
         finalTwoPartyVSDemocratic = dem/(dem + rep) * 100) %>%
  dplyr::select(-year, -State) %>%
  left_join(df %>% distinct(state, State), by = c("state_po" = "state"))
states_2020_ordered_lower <- results_2020 %>% filter(!is.na(State)) %>%
  arrange(finalTwoPartyVSDemocratic) %>% pull(State)
us_regions <- read_csv("dta/us census bureau regions and divisions.csv")
###############################################################################
## Model for scales
m <- file.path("src/stan/polling_error_fat_tails",
               "polling_error_fat_tails_student_t.stan")
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
  left_join(us_regions, by = c("state" = "State Code")) %>%
  left_join(data.frame(x = 1:300,
                       t = sort(rep(1:6, 50)),
                       s = rep(1:50, 6)))

indexes <- data.frame(x = 1:300,
                      t = sort(rep(1:6, 50)),
                      s = rep(1:50, 6)
)

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
    corr_x = indexes %>% pull(x),
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
               "polling_error_fat_tails_normal.stan")
mod_normal <- cmdstan_model(m_normal)
data_list <- list(
  N = nrow(df),
  T = df %>% pull(t) %>% max(),
  S = df %>% pull(s) %>% max(),
  x = df %>% pull(x),
  y = df %>% pull(y),
  n = df %>% pull(n),
  outcome = df %>% pull(outcome),
  corr_x = indexes %>% pull(x)
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
loo_model_weights(loo_list)
weight_frame <- data.frame(
  model_name = rownames(as.matrix(loo_model_weights(loo_list, method = "pseudobma"))),
  weight = as.matrix(loo_model_weights(loo_list, method = "pseudobma"))
) %>%
  mutate(nu = as.integer(str_remove(model_name, "[^\\d]+")))
write_rds(weight_frame, "output/weight_frame.Rds")







## Compare individually against normal
for (i in seq(2, 30, 2)){
  loo_list_compare <- list(
    loo_list[[paste0("nu", i)]],
    loo_list[["normal"]]
  )
  print(loo_model_weights(loo_list_compare))
}

fit_normal$loo()






