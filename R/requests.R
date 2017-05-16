#####################
# Client library in R
#####################

#' Initializing the SMART Client
#'
#' This function creates an object that contains the URL of FGLab and ID of your experiment
#' @param url The URL of FGLab. Defaults to Localhost:5080
#' @param id Experiment ID from FGLab. This is provided from the command line
#' @keywords initialization
#' @examples
#' client = Client(url="https://localhost:5080", id)


set_config( config( ssl_verifypeer = 0, ssl_verifyhost=0 ) )


#Temp
self_url <- "https://localhost:5080"
self_id <- "5911a8cc0331d4511cb10b6f"
url <- paste0(self_url,"/api/v1/runs/", self_id)



Client <- function(url="https://localhost:5080", id){
  # Dependencies
  library(httr)
  library(rjson)
  
  instance <- setClass(
    # Set the name for the class
    "instance",
    # Define the slots
    slots = c(
      url = "character",
      id   = "character"
    )
  )
  
  init_client <- new("instance", url=url, id=id)
  return(init_client)
}

#' Sending files
#' 
#' Sends an arbitrary file over PUT request to FGLab
#' @param file The filepath

send_file <- function(file, session=client){
  mylist <- list()
  myfile <- upload_file(file)
  mylist[['file']] <- myfile
  url <- paste0(session@url,"/api/v1/runs/", session@id, "/file")
  PUT(url, body=mylist)
}

#' Sending metrics
#' 
#' Sends an arbitrary metric over PUT request to FGLab.
#' @param metric The metric name
#' @value value The metric value

send_metric <- function(metric,value, session=client){
  mylist <- list()
  mylist[[metric]] <- value
  json <- list("_scores" = mylist)
  url <- paste0(session@url,"/api/v1/runs/", session@id)
  PUT(url,body=json,encode="json",verbose())
}

#' Sending values
#' 
#' Sends an arbitrary value over PUT request to FGLab. Works similarly to send_metric but the results are displayed differently

send_value <- function(name, value, session=client){
  mylist <- list()
  mylist[[name]] <- value
  url <- paste0(session@url,"/api/v1/runs/", session@id)
  PUT(url,body=mylist,encode="json",verbose())
}

#' Sending notes
#' 
#' Sends arbitrary note over PUT request to FGLab. 
#' @param value The string content

send_note <- function(value, session=client){
  json <- list("_notes" = value)
  url <- paste0(session@url,"/api/v1/runs/", session@id)
  PUT(url,body=json,encode="json",verbose())
}

#' Sending logs
#' 
#' Sends arbitrary log over PUT request to FGLab. 
#' @param value The string content

send_log <- function(msg,type="stdout", session=client){
  mylist <- list()
  mylist[["type"]] <- type
  mylist[["msg"]] <- msg
  url <- paste0(session@url,"/api/v1/runs/", session@id, "/logs")
  PUT(url,body=mylist,encode="json",verbose())
}

################# Chart generation

#' Generating time series charts
#' 
#' Send an arbitrary number of time series graphs to be displayed in FGLab


send_chart <- function(var_names, values, session=client ){
  top <- list(columnNames=as.list(var_names))
  mylist <- list()
  mylist[[var_names[1]]] <- "x1"
  mylist[[var_names[2]]] <- "x2"
  #mid <- list(data=list(xs=list(train="x1", val="x2"),columns=values))
  mid <- list(data=list(xs=mylist,columns=values))
  bottom <- list(axis=c(list(x=list(label=list(text="Iterations"))) , list(y=list(label=list(text="Losses")))))
  charts <- list("_charts"=c(top,mid,bottom))
  url <- paste0(session@url,"/api/v1/runs/", session@id)
  PUT(url,body=charts,encode="json")
}

