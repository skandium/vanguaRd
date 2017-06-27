# Make sure your libpaths are right!
.libPaths("C:/Users/peeterm/Documents/R/win-library/3.4")

source("R/requests.R")
library(RSNNS)
data(iris)

parameters <- list(param1=0.1,
                   size = 1,
                   decay= 0,
                   astring="Test string")

vanguard_init("http://localhost:5080", "Test R", "Test Iris",
              parameters, "R/example.R", tags=c("R", "trial"))

print("this is a test message")
print(paste0("param1", vanguard_settings$args$param1))
print(paste0("astring", vanguard_settings$args$astring))
send_file("DESCRIPTION")

irisValues <- iris[,1:4]
irisTargets <- decodeClassLabels(iris[,5])

iris <- splitForTrainingAndTest(irisValues, irisTargets, ratio=0.15)
iris <- normTrainingAndTestSet(iris)

m <- mlp(iris$inputsTrain, iris$targetsTrain,
         learnFuncParams = c(vanguard_settings$args$param1),
         size = rep(5, vanguard_settings$args$size),
         inputsTest=iris$inputsTest, targetsTest=iris$targetsTest
)

send_metric("Last Iterative Fit Error", tail(m$IterativeFitError, 1))
send_metric("Last Iterative Test Error", tail(m$IterativeTestError, 1))

send_value("param1", vanguard_settings$args$param1)
send_value("size", vanguard_settings$args$size)
send_value("astring", vanguard_settings$args$astring) # TODO for some reason only the last metric I send is shown in FGLab?

png("iferror.png")
plot(m$IterativeFitError)
dev.off()

png("iterror.png")
plot(m$IterativeTestError)
dev.off()

if (file.exists("iferror.png")) send_file("iferror.png")
if (file.exists("iterror.png")) send_file("iterror.png")

cat("a final message")
