context("Potential Outcomes")

test_that("custom po handler", {

  # draw POs for it without arguments

  my_po_function <- function(data) {
    data$Y_Z_0 <- with(data, .25 + extra)
    data$Y_Z_1 <- with(data, extra)
    data
  }

  ##debugonce(declare_potential_outcomes)
  my_po_custom <- declare_potential_outcomes(handler = my_po_function)

  rm(my_po_function)
  pop_custom <- my_po_custom(sleep)

  expect_equal(colnames(pop_custom), c("extra", "group", "ID", "Y_Z_0", "Y_Z_1"))
})

test_that("custom po handler with args", {

  ## draw POs for it with arguments

  my_po_function <- function(data, q) {
    data$Y_Z_0 <- with(data, q + extra)
    data$Y_Z_1 <- with(data, extra)
    data
  }

  ##debugonce(declare_potential_outcomes)
  my_po_custom <- declare_potential_outcomes(
    handler = my_po_function, q = 2)

  ##debugonce(my_po_custom)
  rm(my_po_function)
  pop_custom <- my_po_custom(sleep)

  expect_equal(colnames(pop_custom), c("extra", "group", "ID", "Y_Z_0", "Y_Z_1"))
  expect_equal(pop_custom$Y_Z_1[1] - pop_custom$Y_Z_0[1] , -2)
})




test_that("PO as discrete variables works", {

  my_potential_outcomes <- declare_potential_outcomes(
    Y_Z_0 = extra,
    Y_Z_1 = extra + 5)

  expect_equal(colnames(my_potential_outcomes(sleep)),
               c("extra", "group", "ID", "Y_Z_0", "Y_Z_1"))


})



test_that("PO as a formula works", {

  my_potential_outcomes_explicit <-
    declare_potential_outcomes(formula = R ~ rbinom(n = N, size = 1, prob = 1))

  my_potential_outcomes_implicit <-
    declare_potential_outcomes(R ~ rbinom(n = N, size = 1, prob = 1))

  expect_identical(
    my_potential_outcomes_explicit(sleep),
    my_potential_outcomes_implicit(sleep)
  )

})


test_that("POs at a higher level",{

  library(dplyr)
  my_population <- declare_population(
    villages = add_level(N = 3, elevation = rnorm(N)),
    citizens = add_level(N = 4, income = runif(N))
  )

  pop <- my_population()

  # Four ways of doing the same thing

  # with "level" argument in a "formula" version
  my_potential_outcomes_formula <-
    declare_potential_outcomes(
        formula = Y_vil ~ elevation + 5 + 2*Z,
        level = villages
      )
  my_potential_outcomes_formula(pop)

  # with "level" argument in a "formula" version
  my_potential_outcomes_formula <-
    declare_potential_outcomes(
      formula = Y_vil ~ elevation + 5 + 2*Z,
      level = villages
    )
  my_potential_outcomes_formula(pop)


  # with "level" argument in a "discrete" version
  my_potential_outcomes_discrete <-
    declare_potential_outcomes(
      Y_vil_Z_0 = elevation + 5,
      Y_vil_Z_1 = elevation + 5 + 2,
      level = villages
    )

  my_potential_outcomes_discrete(pop)

  # with custom function
  my_custom_PO <- function(data){
    data %>%
    group_by(villages) %>%
      mutate(Y_vil_Z_0 = elevation + 5,
             Y_vil_Z_1 = elevation + 5 + 2)
  }


  my_custom_PO(pop)

  my_potential_outcomes <-
    declare_potential_outcomes(
      formula = Y_vil ~ elevation + 5 + 2*Z
    )

  expect_warning(
    my_design <-
      declare_design(
        pop,
        group_by(villages),
        my_potential_outcomes
      ),
    "Potential outcome is the final step in the design."
  )

  draw_data(my_design)

})


test_that("error if you try to draw POs at a level using a variable that doesn't exist at that level",{

  my_population <- declare_population(
    villages = add_level(N = 3, elevation = rnorm(N)),
    citizens = add_level(N = 4, income = runif(N))
  )

  pop <- my_population()

  my_potential_outcomes_formula <-
    declare_potential_outcomes(
      formula = Y_vil ~ elevation + income + 5,
      level = villages
    )

  expect_error(my_potential_outcomes_formula(pop))

})


test_that("Potential outcomes with multiple assignment variables",{

  beta <- c(1, 3)

  my_potential_outcomes_formula <-
    declare_potential_outcomes(
      formula = test ~ extra + cbind(z1, z2) %*% beta,
      conditions = list(z1=0:1, z2=1:2)
    )
  out <- my_potential_outcomes_formula(sleep)
  with(out, {
       expect_equal(extra + 3, test_z1_0_z2_1)
       expect_equal(extra + 4, test_z1_1_z2_1)
       expect_equal(extra + 6, test_z1_0_z2_2)
       expect_equal(extra + 7, test_z1_1_z2_2)
  })

})


test_that("Restore existing variables to be unchanged",{


  my_potential_outcomes_formula <-
    declare_potential_outcomes(
      formula = test ~ extra + group,
      conditions = list(group=1:2)
    )
  expect_identical(
     my_potential_outcomes_formula(sleep)$group,
     sleep$group)

})


test_that("PO warns if unnamed dot",{


  expect_warning(
    my_potential_outcomes_formula <- declare_potential_outcomes(NULL, sleep)
  )

})


test_that("Binary Potential outcomes",{


  my_potential_outcomes_formula <-
    declare_potential_outcomes(
      Y ~ draw_binary(prob=plogis(1000*Z + extra))
    )

  out <- my_potential_outcomes_formula(sleep)
  expect_true(all(out$Y_Z_1 == 1))

})


test_that("Reveal step injected (default names)",{

  N <- 100

  pop <- declare_population(N=N, foo=rnorm(N))
  po <- declare_potential_outcomes(Y~Z+foo)
  assn <- declare_assignment(N=N, m=N/2)
  expect_warning(d <- declare_design(pop, po, assn), "inject a `declare_reveal")
  expect_true("Y" %in% colnames(draw_data(d)))

})


test_that("Reveal step injected (default names)",{

  N <- 100

  # Assn is buggy, but masked by po autoreveal error
  pop <- declare_population(N=N, foo=rnorm(N))
  po <- declare_potential_outcomes(Q~T+foo, assignment_variables=list(T=1:3))
  assn <- declare_assignment(N=N, m=N/2, assignment_variable=T)
  expect_warning( d <- declare_design(pop, po, assn) )
  # Not autoreveal injected, so length 3
  expect_length(d, 3)

  # Now we see it
  po <- declare_potential_outcomes(Q~T+foo, conditions=list(T=1:3))
  expect_warning(d <- declare_design(pop, po, assn), "never later revealed")
  expect_error(draw_data(d), "Q_T_0")

  # Fix it
  assn <- declare_assignment(N=N, prob_each=c(1,1,1)/3, conditions=1:3, assignment_variable="T")
  expect_warning(d <- declare_design(pop, po, assn), "never later revealed")
  expect_true("Q" %in% colnames(draw_data(d)))

  expect_warning(d <- declare_design(pop, assn, po, identity), "inject a `declare_reveal")
  expect_equal(attr(d[[4]], "step_type"), "reveal_outcomes")

})


test_that("Reveal step injected after another injected reveal step",{

  N <- 100

  pop <- declare_population(N=N, foo=rnorm(N))
  po <- declare_potential_outcomes(Y~draw_binary(plogis(Z+foo)))
  po2 <- declare_potential_outcomes(Q~Y+foo, conditions=list(Y=0:1))
  assn <- declare_assignment(N=N, m=N/2)

  expect_warning(d <- declare_design(pop, po, po2,assn), "inject a `declare_reveal[(]Q, Y")
  expect_true("Y" %in% colnames(draw_data(d)))

  expect_equal(attr(d[[5]], "step_type"), "reveal_outcomes")
  expect_equal(attr(d[[6]], "step_type"), "reveal_outcomes")
})


test_that("Multiple assignment variables in PO",{

  po <- declare_potential_outcomes(Y~Z1 + Z2, conditions=list(Z1=0:1, Z2=0:1))

  expect_length(colnames(po(sleep)) %i% c("Y_Z1_0_Z2_0", "Y_Z1_1_Z2_0", "Y_Z1_0_Z2_1", "Y_Z1_1_Z2_1"), 4)
})


test_that("handler dispatches correctly",{

  po <- potential_outcomes_handler(Y~Z1 + Z2, conditions=expand.grid(Z1=0:1, Z2=0:1), assignment_variables=c("Z1", "Z2"), data=sleep, level=NULL)

  po2 <- potential_outcomes_handler(NULL, Y_Z1_0_Z2_0=0, Y_Z1_0_Z2_1=1,Y_Z1_1_Z2_0=1,Y_Z1_1_Z2_1=2, data=sleep, level=NULL)

  expect_length(names(po) %i% c("Y_Z1_0_Z2_0", "Y_Z1_1_Z2_0", "Y_Z1_0_Z2_1", "Y_Z1_1_Z2_1"), 4)
  expect_length(names(po2) %i% c("Y_Z1_0_Z2_0", "Y_Z1_1_Z2_0", "Y_Z1_0_Z2_1", "Y_Z1_1_Z2_1"), 4)

})

