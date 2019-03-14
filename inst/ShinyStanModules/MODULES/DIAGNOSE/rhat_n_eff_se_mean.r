rhat_n_eff_se_meanUI <- function(id){
  # for internal namespace structure
  ns <- NS(id)

  tagList(
    wellPanel(
      fluidRow(
        column(width = 8,
               splitLayout(
                 sliderInput(
                   ns("rhat_threshold"),
                   withMathJax("\\(\\hat{R} \\text{ warning threshold}\\) "),
                   ticks = FALSE,
                   value = 1.1,
                   min = 1,
                   max = 1.2,
                   step = 0.01
                 ),
                 sliderInput(
                   ns("n_eff_threshold"),
                   withMathJax("\\(n_{eff} \\text{ / } \\textit{N} \\text{ warning threshold}\\) "),
                   ticks = FALSE,
                   value = 10,
                   min = 0,
                   max = 100,
                   step = 5,
                   post = "%"
                 ),
                 sliderInput(
                   ns("mcse_threshold"),
                   "\\(\\text{se}_{mean} \\text{ / } \\textit{sd} \\text{ warning threshold}\\) ",
                   ticks = FALSE,
                   value = 10,
                   min = 0,
                   max = 100,
                   step = 5,
                   post = "%"
                 )
               )
        ),
        column(width = 4, align = "right",
               splitLayout(
                 radioButtons(
                   ns("report"),
                   label = h5("Report"),
                   choices = c("Omit", "Include"),
                   select = "Omit"
                 ),
                 div(style = "width: 100px;"
                 )
               )
        )
      )
    ),
    fluidRow(
      column(width = 12,
             splitLayout(
               verticalLayout(
                 h4(withMathJax("\\(\\hat{R}\\)")),
                 textOutput(ns("rhat"))   
               ),
               verticalLayout(
                 h4(withMathJax("\\(n_{eff} / N\\)")),
                 textOutput(ns("n_eff"))
               ),
               verticalLayout(
                 h4(withMathJax("\\(mcse / sd\\)")),
                 uiOutput(ns("se_mean"))
               )
             )
      )
    ),
    fluidRow(
      column(width = 4, plotOutput(ns("rhatPlot"))),
      column(width = 4, plotOutput(ns("n_effPlot"))),
      column(width = 4, plotOutput(ns("se_meanPlot")))
    )
  )
}
  

rhat_n_eff_se_mean <- function(input, output, session){
  
  
  plotOut_rhat <- function(){
    color_scheme_set("blue")
    mcmc_rhat_hist(shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary[, "Rhat"])
  }
  
  output$rhatPlot <- renderPlot({
    plotOut_rhat()
  })
  
  plotOut_n_eff <- function(){
    color_scheme_set("blue")
    mcmc_neff_hist(shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary[, "n_eff"] / ((shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_iter - shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_warmup) * shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_chain))
  }
  
  output$n_effPlot <- renderPlot({
    plotOut_n_eff()
  })
  
  plotOut_se_mean <- function(){
    se_sd_table <- tibble(diagnostic = rep("se_sd_ratio", length(shinystan:::.sso_env$.SHINYSTAN_OBJECT@param_names)),
                          parameter = as.factor(shinystan:::.sso_env$.SHINYSTAN_OBJECT@param_names),
                          value = shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary[, "se_mean"] / shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary[, "sd"],
                          rating = cut(shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary[, "se_mean"] / shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary[, "sd"], breaks = c(Inf, 0.5, 0.1, 0), 
                                       labels = c("low", "ok", "high")),
                          description = as.character(cut(shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary[, "se_mean"] / shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary[, "sd"], breaks = c(Inf, 0.5, 0.1, 0), 
                                                         labels = c(expression(MC[se] / sd <= 0.1),
                                                                    expression(MC[se] / sd <= 0.5),
                                                                    expression(MC[se] / sd > 0.5)))))
    
    color_scheme_set("blue") 
    ggplot(data = se_sd_table, mapping = aes_(x = ~value, color = ~rating, fill = ~rating)) + 
      geom_histogram(size = 0.25, na.rm = TRUE) + 
      labs(x = expression(MC[se] / sd),y = NULL) + 
      bayesplot:::dont_expand_y_axis(c(0.005, 0)) + bayesplot_theme_get() + 
      yaxis_title(FALSE) + yaxis_text(FALSE) + yaxis_ticks(FALSE) +
      theme(legend.position = "none")
  }
  
  output$se_meanPlot <- renderPlot({
    plotOut_se_mean()
  })
  
  
  output$rhat <- renderText({
    
    bad_rhat <- rownames(shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary)[shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary[, "Rhat"] > reactive(input$rhat_threshold)()]
    bad_rhat <- bad_rhat[!is.na(bad_rhat)]
    rhatWarning <- paste0("The following parameters have an Rhat value above ", 
                          reactive(input$rhat_threshold)(), ":<br>",
                          paste(bad_rhat, collapse = ", "))
    
    if(length(bad_rhat) < 1){
      paste0("No parameters have an Rhat value above ", reactive(input$rhat_threshold)(), ".")
    } else {
      rhatWarning
    }
  })
  
  output$n_eff <- renderText({
    
    bad_n_eff <- rownames(shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary)[shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary[, "n_eff"] / ((shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_iter- shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_warmup) * shinystan:::.sso_env$.SHINYSTAN_OBJECT@n_chain) < 
                                         (reactive(input$n_eff_threshold)() / 100)]
    bad_n_eff <- bad_n_eff[!is.na(bad_n_eff)]
    n_effWarning <- paste0("The following parameters have an effective sample size less than ", 
                           reactive(input$n_eff_threshold)(), "% of the total sample size:<br>",
                           paste(bad_n_eff, collapse = ", "))
    
    if(length(bad_n_eff) < 1){
      paste0("No parameters have an effective sample size less than ",
                  reactive(input$n_eff_threshold)(), "% of the total sample size.")
    } else {
      n_effWarning
    }
  })
  
  
  output$se_mean <- renderUI({
    
    bad_se_mean <- rownames(shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary)[shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary[, "se_mean"] / shinystan:::.sso_env$.SHINYSTAN_OBJECT@summary[, "sd"] > 
                                           (reactive(input$mcse_threshold)() / 100)]
    bad_se_mean <- bad_se_mean[!is.na(bad_se_mean)]
    se_meanWarning <- paste0("The following parameters have a Monte Carlo standard error greater than ",
                             reactive(input$mcse_threshold)(), "% of the posterior standard deviation:<br>",
                             paste(bad_se_mean, collapse = ", "))
    
    if(length(bad_se_mean) < 1){
      HTML(paste0("<div style='background-color:lightblue; color:black; 
                  padding:5px; opacity:.3'>",
                  "No parameters have a standard error greater than ", 
                  reactive(input$mcse_threshold)(), "% of the posterior standard deviation.", 
                  "</div>"))
    } else {
      HTML(paste0("<div style='background-color:red; color:white; 
                  padding:5px; opacity:.3'>",
                  se_meanWarning, "</div>"))
    }
  })
  
  return(reactive({
    list("rhatPlot" = plotOut_rhat(),
         "n_effPlot" = plotOut_n_eff(),
         "se_meanPlot" = plotOut_se_mean())
  }))
  
}