  source("R/requests.R")

  parameters <- list(param1=123,
                     astring="12312")

  vanguard_init("http://localhost:5080", "Taivo R dev project 1", "test experiment 3",
                parameters, "R/example.R", tags=c("tag1", "tag2"))

  print("this is a test message")

  send_metric("test metric", 42.123123)
  send_metric("param1", vanguard_settings$args$param1)
  send_metric("astring", vanguard_settings$args$astring) # TODO for some reason only the last metric I send is shown in FGLab?
  cat("a final message")
