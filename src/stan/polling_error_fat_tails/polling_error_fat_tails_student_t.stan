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
  vector[S * T] xi_student_t;
}
model {
  xi_student_t ~ student_t(nu,0, 0.1);
  y ~ binomial_logit(n, logit_outcome + xi_student_t[x]);
}
generated quantities {
  vector[N] log_lik;
  for (ii in 1:N){
    log_lik[ii] = binomial_logit_lpmf(y[ii] | n[ii], logit_outcome[ii] + xi_student_t[x[ii]]);
  }
}
