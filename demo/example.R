# Make sure that you have right libpaths!
.libPaths("C:/Users/peeterm/Documents/R/win-library/3.4")

source("R/requests.R")

parameters <- list(param1=123,
                   astring="12312")

vanguard_init("http://localhost:5080", "Example project in R", "Example experiment in R",
              parameters, "R/example.R", tags=c("tag1", "tag2"))

print("this is a test message")
print(paste0("param1", vanguard_settings$args$param1))
print(paste0("astring", vanguard_settings$args$astring))
send_file("DESCRIPTION")

send_value("test metric", 42.123123)
send_value("param1", vanguard_settings$args$param1)
send_value("astring", vanguard_settings$args$astring) # TODO for some reason only the last metric I send is shown in FGLab?
cat("a final message")

if (file.exists("iferror.png")) send_file("iferror.png")
if (file.exists("iterror.png")) send_file("iterror.png")

cat("a final message")
