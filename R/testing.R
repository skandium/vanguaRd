source("R/requests.R")

parameters <- list(param1=123,
                   leet=1337,
                   astring="12312")
vanguard_init("http://localhost:5080", "testing R project v2", "test experiment",
              parameters, "R/testing.R", tags=c("tag1", "tag2"))


send_metric("test metric", 42.123123)
#print(toJSON(.get_options_dict()))
