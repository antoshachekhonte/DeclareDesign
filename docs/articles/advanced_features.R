## ----echo=FALSE, warning=FALSE, message=FALSE----------------------------
set.seed(42)
library(DeclareDesign)
options(digits=2)

my_population <-
  declare_population(N = 1000,
  income = rnorm(N),
  age = sample(18:95, N, replace = TRUE))

pop <- my_population()

my_potential_outcomes <- declare_potential_outcomes(
  formula = Y ~ .25 * Z + .01 * age * Z)
pop_pos <- my_potential_outcomes(pop)

my_sampling <- declare_sampling(n = 250)
smp <- my_sampling(pop_pos)

my_assignment <- declare_assignment(m = 25)
smp <- my_assignment(smp)

my_estimand <- declare_estimand(ATE = mean(Y_Z_1 - Y_Z_0))

smp <- reveal_outcomes(smp)

## ----echo=TRUE, results="hide"-------------------------------------------
m_arm_trial <- function(numb){
  my_population <- declare_population(
    N = numb, income = rnorm(N), age = sample(18:95, N, replace = T))

  my_potential_outcomes <- declare_potential_outcomes(
    formula = Y ~ .25 * Z + .01 * age * Z)
  my_sampling <- declare_sampling(n = 250)
  my_assignment <- declare_assignment(m = 25)
  my_estimand <- declare_estimand(ATE = mean(Y_Z_1 - Y_Z_0))
  my_estimator_dim <- declare_estimator(Y ~ Z, estimand = my_estimand)
  my_design <- declare_design(my_population,
                              my_potential_outcomes,
                              my_estimand,
                              my_sampling,
                              my_assignment,
                              reveal_outcomes,
                              my_estimator_dim)
  return(my_design)
}

my_1000_design <- fill_out(template = m_arm_trial, numb = 1000)
head(draw_data(my_1000_design))

## ----echo=FALSE----------------------------------------------------------
knitr::kable(head(draw_data(my_1000_design)))

## ----echo=TRUE, results="hide"-------------------------------------------
my_potential_outcomes_continuous <- declare_potential_outcomes(
  formula = Y ~ .25 * Z + .01 * age * Z, conditions = seq(0, 1, by = .1))

continuous_treatment_function <- function(data){
 data$Z <- sample(seq(0, 1, by = .1), size = nrow(data), replace = TRUE)
 data
}

my_assignment_continuous <- declare_assignment(handler = continuous_treatment_function)

my_design <- declare_design(my_population(),
                            my_potential_outcomes_continuous,
                            my_assignment_continuous,
                            reveal_outcomes)

head(draw_data(my_design))

## ----echo=FALSE----------------------------------------------------------
knitr::kable(head(draw_data(my_design)))

## ----echo=TRUE, results="hide"-------------------------------------------
my_potential_outcomes_attrition <- declare_potential_outcomes(
  formula = R ~ rbinom(n = N, size = 1, prob = pnorm(Y_Z_0)))

my_design <- declare_design(my_population(),
                            my_potential_outcomes,
                            my_potential_outcomes_attrition,
                            my_assignment,
                            reveal_outcomes(outcome_variables = "R"),
                            reveal_outcomes(attrition_variables = "R"))

head(draw_data(my_design)[, c("ID", "Y_Z_0", "Y_Z_1", "R_Z_0", "R_Z_1", "Z", "R", "Y")])

## ----echo=FALSE----------------------------------------------------------
knitr::kable(head(draw_data(my_design)[, c("ID", "Y_Z_0", "Y_Z_1", "R_Z_0", "R_Z_1", "Z", "R", "Y")]))

## ----echo=TRUE, results="hide"-------------------------------------------
stochastic_population <- declare_population(
  N = sample(500:1000, 1), income = rnorm(N), age = sample(18:95, N, replace = TRUE))

c(nrow(stochastic_population()), 
  nrow(stochastic_population()), 
  nrow(stochastic_population()))

