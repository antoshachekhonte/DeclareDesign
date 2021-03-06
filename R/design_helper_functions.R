#' Explore your design
#'
#' @param design A design created by \code{\link{declare_design}}.
#'
#' @examples
#'
#' design <- declare_design(
#'   my_population = declare_population(N = 500, noise = rnorm(N)),
#'   my_potential_outcomes = declare_potential_outcomes(Y ~ noise + Z * rnorm(N, 2, 2)),
#'   my_sampling = declare_sampling(n = 250),
#'   my_estimand = declare_estimand(ATE = mean(Y_Z_1 - Y_Z_0)),
#'   dplyr::mutate(noise_sq = noise^2),
#'   my_assignment =  declare_assignment(m = 25),
#'   my_reveal = declare_reveal(),
#'   my_estimator = declare_estimator(Y ~ Z, estimand = "my_estimand")
#' )
#'
#' design
#'
#' df <- draw_data(design)
#'
#' estimates <- get_estimates(design)
#' estimands <- get_estimands(design)
#'
#' @name post_design
NULL


###############################################################################
# For fan-out execution, convert the vector representation to (end, n) pairs

check_sims <- function(design, sims) {
  n <- length(design)
  if(!is.data.frame(sims)){
    if( length(sims) == n){
      sims_full <- sims
    }
    else if(is.character(names(sims))) {
      sims_full <- rep(1, n)
      design_labels <- as.character(lapply(design, attr, "label"))
      i <- match(names(sims), design_labels)
      sims_full[i] <- sims
    } else if (length(sims) != n) {
      sims_full <- c(sims, rep(1, n))[1:n]
    }

    ret <- data.frame(end=1:n, n=sims_full)
  }
  else ret <- sims

  # Compress sequences of ones into one partial execution
  include <- rep(TRUE,n)
  last_1 <- FALSE
  for(i in n:1){
    if(!last_1) include[i] <- TRUE
    else if(ret[i, "n"] == 1 && last_1) include[i] <- FALSE

    last_1 <- ret[i, "n"] == 1
  }

  ret[include, ,drop=FALSE]
}

#' Execute a design
#'
#' @param design a DeclareDesign object
#'
#' @export
conduct_design <- function(design) conduct_design_internal(design)


conduct_design_internal <- function(design, ...) UseMethod("conduct_design_internal", design)

conduct_design_internal.default <- function(design, current_df=NULL, results=NULL, start=1, end=length(design), ...) {

  if(!is.list(results)) {
    results <- list(estimand=vector("list", length(design)),
                    estimator=vector("list", length(design)))
  }

  for (i in seq(start, end)) {
    step <- design[[i]]

    causal_type <- attr(step, "causal_type")
    step_type <- attr(step, "step_type")

    tryCatch(
      nxt <- step(current_df),
      error = function(err) {
        stop(simpleError(sprintf("Error in step %d (%s):\n\t%s", i, attr(step, "label") %||% "", err)))
      }
    )

    # if it's a dgp
    if ("dgp" %in% causal_type) {
      current_df <- nxt
    } else if(step_type %in% names(results) ) {
      results[[step_type]][[i]] <- nxt
    }
  }

  if(i == length(design)) {
    if("estimator" %in% names(results)){
      results[["estimates_df"]] <-  rbind_disjoint(results[["estimator"]])
      results[["estimator"]] <- NULL
    }
    if("estimand" %in% names(results)){
      results[["estimands_df"]] <- rbind_disjoint(results[["estimand"]])
      results[["estimand"]] <- NULL

    }
    if("current_df" %in% names(results)){
      results[["current_df"]] <- current_df
    }
    results

  } else execution_st(design=design, current_df=current_df, results=results, start=i+1, end=length(design))

}

conduct_design_internal.execution_st <- function(design, ...) do.call(conduct_design_internal.default, design)

#' Build an execution strategy object
#'
#' @param design a design
#' @param current_df a data.frame
#' @param results a list of intermediate results
#' @param start index of starting step
#' @param end  index of ending step
#'
#' @export
execution_st <- function(design, current_df=NULL, results=NULL, start=1, end=length(design)){
  # An execution state are the arguments needed to run conduct_design
  structure(
    list(design=design, current_df=current_df, results=results, start=start, end=end),
    class="execution_st"
  )
}


#' @rdname post_design
#'
#' @export
draw_data <- function(design) {
  conduct_design_internal(design, results=list(current_df=0))$current_df
}

#' @rdname post_design
#'
#' @export
get_estimates <- function(design) {
  results=list("estimator"=vector("list", length(design)))
  conduct_design_internal.default(design, results=results)$estimates_df
}

#' @rdname post_design
#'
#' @export
get_estimands <- function(design) {
  results=list("estimand"=vector("list", length(design)))
  conduct_design_internal.default(design, results=results)$estimands_df
}

#' Obtain the preferred citation for a design
#'
#' @param design a design object created by \code{declare_design}
#'
#' @param ... options for printing the citation if it is a BibTeX entry
#'
#' @export
cite_design <- function(design, ...) {
  citation <- Filter(function(step) attr(step, "causal_type") == 'citation', design)[[1]]()
  if (class(citation) == "bibentry") {
    print(citation, style = "bibtex", ... = ...)
    cat("\n")
  }
  print(citation, style = "text", ... = ...)
  invisible(design)
}

#' @export
print.design_step <- function(x, ...) {
  print(attr(x, "call"))
  # invisible(summary(x))
}


#' @export
print.design <- function(x, ...) {
  print(summary(x))
  # invisible(summary(x))
}

#' @export
print.summary.design <- function(x, ...) {
  cat("\nDesign Summary\n\n")

  if (!is.null(x$title)) {
    cat("Study title: ", x$title, ifelse(is.null(x$authors), "\n\n", ""), sep = "")
  }

  if (!is.null(x$authors)) {
    cat(
      ifelse(!is.null(x$title), "\n", ""),
      "Authors: ",
      paste0(x$authors, collapse = ", "),
      "\n\n",
      sep = ""
    )
  }

  if (!is.null(x$description)) {
    cat(x$description, "\n\n")
  }

  for (i in 1:max(length(x$variables_added), length(x$quantities_added))) {
    step_name <- if(is.null(x$call[[i]])) "" else deparse(x$call[[i]])
    step_class <-
      ifelse(
        x$function_types[[i]] != "unknown",
        gsub("_", " ", x$function_types[[i]]),
        "custom data modification"
      )

    dash_width <-
      max(c(80 - 11 - nchar(i) - nchar(step_class) - nchar(step_name[1]), 0))

    cat(
      "Step ",
      i,
      " (",
      step_class,
      "): ",
      step_name,
      " ",
      paste0(rep("-", dash_width), collapse = ""),
      "\n\n",
      sep = ""
    )

    if (!is.null(x$N[[i]])) {
      cat(x$N[[i]], "\n\n")
    }

    if (!is.null(x$formulae[[i]])) {
      cat("Formula:", deparse(x$formula[[i]]), "\n\n")
    }
    if (is.character(x$extra_summary[[i]])) {
      cat(x$extra_summary[[i]], "\n\n")
    }

    if (!is.null(x$quantities_added[[i]])) {
      if (class(x$quantities_added[[i]]) == "data.frame") {
        cat("A single draw of the ", x$function_types[[i]], ":\n", sep = "")
        print(x$quantities_added[[i]], row.names = FALSE)
        cat("\n")
      } else {
        cat(x$quantities_added[[i]], sep = "\n")
        cat("\n")
      }
    }
    if (!is.null(x$variables_added[[i]])) {
      for (j in seq_along(x$variables_added[[i]])) {
        cat("Added variable:", names(x$variables_added[[i]])[j], "\n")
        print(x$variables_added[[i]][[j]], row.names = FALSE)
        cat("\n")
      }
    }
    if (!is.null(x$variables_modified[[i]])) {
      for (j in seq_along(x$variables_modified[[i]])) {
        cat("Altered variable:",
            names(x$variables_modified[[i]])[j],
            "\n  Before: \n")
        print(x$variables_modified[[i]][[j]][["before"]], row.names = FALSE)
        cat("\n  After:\n")
        print(x$variables_modified[[i]][[j]][["after"]], row.names = FALSE)
        cat("\n")
      }
    }
  }

  if (!is.null(x$citation)) {
    cat("Citation:\n")
    print(x$citation)
  }

  invisible(x)
}

#' @export
str.design_step <- function(object, ...) cat("design_step:\t", paste0(deparse(attr(object, "call"), width.cutoff = 500L), collapse=""), "\n")

#' @export
str.seed_data <- function(object, ...) cat("seed_data:\t", paste0(deparse(attr(object, "call"), width.cutoff = 500L), collapse=""), "\n")



### A wrapper around conduct design for fan-out execution strategies
###
###
fan_out <- function(design, fan) {

  st <- list( execution_st(design) )

  for(i in 1:nrow(fan)){

    end <- fan[i, "end"]
    n   <- fan[i, "n"]

    for(j in seq_along(st))
      st[[j]]$end <- end

    st <- st [ rep(seq_along(st), each = n) ]

    st <- future_lapply(seq_along(st), function(j) conduct_design(st[[j]]), future.seed = NA, future.globals = "st")

  }

  st
}
