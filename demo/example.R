library(proekspertlab)
# Make sure that you have right libpaths!
#.libPaths("C:/Users/peeterm/Documents/R/win-library/3.4")
.libPaths(c("/Users/taivo/Library/R/3.2/library",
          "/Library/Frameworks/R.framework/Versions/3.2/Resources/library"))

parameters <- list(param1=123,
                   astring="12312",
                   astring3="default")

vanguard_init("http://localhost:5080", "Example project in R", "Example experiment x in R",
              parameters, "demo/example.R", tags=c("tag1", "tag2"))

print("this is a test message")
print(paste0("param1 ", get_argument("param1")))
print(paste0("astring ", get_argument("astring")))
print(paste0("astring3 ", get_argument("astring3")))
send_file("DESCRIPTION")

send_value("test metric", 42.123123)
send_value("param1", get_argument("param1"))
send_value("astring", get_argument("astring"))
cat("a final message")

if (file.exists("iferror.png")) send_file("iferror.png")
if (file.exists("iterror.png")) send_file("iterror.png")

cat("a final message")
