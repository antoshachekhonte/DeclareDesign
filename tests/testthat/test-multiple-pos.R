library(DeclareDesign)

## would be nice to do with fixed POs

my_population <- declare_population(
  N = 100, income = rnorm(N), age = sample(18:95, N, replace = T))

my_potential_outcomes_Y <- declare_potential_outcomes(
  formula = Y ~ .25 * Z + .01 * age * Z)

my_potential_outcomes_attrition <- declare_potential_outcomes(
  formula = R ~ rbinom(n = N, size = 1, prob = pnorm(Y_Z_0)))

my_assignment <- declare_assignment(m = 25)

my_design <- declare_design(my_population(),
                            my_potential_outcomes_Y,
                            my_potential_outcomes_attrition,
                            my_assignment,
                            step(reveal_outcomes(outcome_variable_name = "Y", assignment_variable_name = "Z")),
                            step(reveal_outcomes(outcome_variable_name = "R", assignment_variable_name = "Z")))

head(draw_data(my_design))