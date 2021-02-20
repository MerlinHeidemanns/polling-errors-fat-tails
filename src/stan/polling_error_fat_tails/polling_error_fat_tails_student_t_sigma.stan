data {
  int N;
  int S; // State
  int T; // Year
  int x[N];
  int y[N];
  int n[N];
  vector[N] outcome;
  real nu;
}
transformed data {
  vector[N] logit_outcome;
  logit_outcome = logit(outcome);
}
parameters {
  vector[S * T] xi_student_t;
  real<lower = 0> sigma;
}
model {
  sigma ~ normal(0, 0.25);
  xi_student_t ~ student_t(nu,0, sigma);
  y ~ binomial_logit(n, logit_outcome + xi_student_t[x]);
}
generated quantities {
  vector[N] log_lik;
  for (ii in 1:N){
    log_lik[ii] = binomial_logit_lpmf(y[ii] | n[ii], logit_outcome[ii] + xi_student_t[x[ii]]);
  }
}
