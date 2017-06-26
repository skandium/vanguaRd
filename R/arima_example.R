##############################
# Time series (pseudo)-forecasting in R
##############################


source("R/requests.R")

parameters <- list(p=3,
                   d=1,
                   q=0,
                   note="Explaining Apple stock price via simple ARIMA model")

vanguard_init("http://localhost:5080", "Series", "R ARIMA",
              parameters, "R/arima.R", tags=c("Time series", "ARIMA", "Stocks"))


if (!require("quantmod")) {
  install.packages("quantmod")
  library(quantmod)
}
library(forecast)
library(data.table)

start <- as.Date("2016-01-01")
end <- as.Date("2017-06-01")

getSymbols("AAPL", src = "yahoo", from = start, to = end)

data <- AAPL$AAPL.Close

dat <- data.table(data)
dat[,logdiff := log(AAPL.Close) - log(shift(AAPL.Close,1L,type="lag"))]
data <- dat$logdiff[2:189]
rm(dat)

fit_arima <- Arima(data,order=c(vanguard_settings$args$p,vanguard_settings$args$d,vanguard_settings$args$q))
#fit_arima <- auto.arima(data)

png(filename="arima.png")
plot(fit_arima$x,col="red",ylab="Log change in Apple stock price",type="l")
lines(fitted(fit_arima),col="blue")
legend(x=75,y=0.05,col=c("red","blue"),legend=c("Actual","Fitted"),lty=1)
dev.off()

send_file("arima.png")

mse <- sqrt(sum(fit_arima$x - fitted(fit_arima))^2)

send_metric("MSE",mse)

note1 <- paste0("AR",1:length(fit_arima$model$phi),": ", as.character(fit_arima$model$phi))
note2 <- paste0("I: ",as.character(fit_arima$model$Delta))
note3 <- paste0("MA",1:length(fit_arima$model$theta),": ", as.character(fit_arima$model$theta))

note <- c(note1,note2,note3)

send_note(note)


