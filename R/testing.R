  source("R/requests.R")

  parameters <- list(param1=123,
                     astring="12312")

  vanguard_init("http://localhost:5080", "Taivo R dev project 1", "test experiment 1",
                parameters, "R/testing.R", tags=c("tag1", "tag2"))

  print("taivo leeet kesk")

  send_metric("test metric", 42.123123)
  send_metric("param1", vanguard_settings$parameters$param1)
  send_metric("astring", vanguard_settings$parameters$astring)
  cat("taivo leeet lõpp")
  #print(toJSON(.get_options_dict()))
