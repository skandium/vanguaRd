source("R/requests.R")

parameters <- list(param1=123,
                   leet=1337,
                   astring="12312")

vanguard_init("http://localhost:5080", "testing R project v3", "test experiment 6",
              parameters, "R/testing.R", tags=c("tag1", "tag2"))

cat("taivo leeet kesk")

send_metric("test metric", 42.123123)
cat("taivo leeet lõpp")
#print(toJSON(.get_options_dict()))
