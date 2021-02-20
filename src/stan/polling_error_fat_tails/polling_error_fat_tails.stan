data {
  int N;
  int S; // State
  int T; // Year
  int x[N];
  int y[N];
  int n[N];
  vector[N] outcome;

  int corr_x[S * T];
  real nu;
}
transformed data {
  vector[N] logit_outcome;
  logit_outcome = logit(outcome);
}
parameters {
  real<lower = 0> sigma_normal;
  real<lower = 0> sigma_student_t;
  vector[S * T] xi_normal;
  vector[S * T] xi_student_t;
  real<lower = 0, upper = 1> alpha;
}
model {
  alpha ~ normal(0.5, 0.5);
  sigma_normal ~ normal(0, 0.1);
  sigma_student_t ~ normal(0, 0.1);
  xi_normal ~ normal(0, 0.1);
  xi_student_t ~ student_t(nu,0, sigma_student_t);
  target += log_sum_exp(log(alpha) + binomial_logit_lpmf(y | n, logit_outcome + xi_normal[x]),
    log1m(alpha) + binomial_logit_lpmf(y | n, logit_outcome + xi_student_t[x]));
}
