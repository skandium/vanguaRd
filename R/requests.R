#####################
# Client library in R
#####################

options(warn=-1) # Turn off warnings while loading libraries
suppressMessages(require(httr))
suppressMessages(require(rjson))
suppressMessages(require(argparser))
suppressMessages(require(dotenv))
options(warn=0)

set_config( config( ssl_verifypeer = 0, ssl_verifyhost=0 ) )

vanguard_settings <- list()
experiment_setup <- list()

.stopQuietly <- function(...) {
  #https://stackoverflow.com/questions/14469522/stop-an-r-program-without-error
  blankMsg <- sprintf("\r%s\r", paste(rep(" ", getOption("width")-1L), collapse=" "));
  stop(simpleError(blankMsg));
}

.get_filename <- function() {
  # https://stackoverflow.com/questions/1815606/rscript-determine-path-of-the-executing-script
  initial.options <- commandArgs(trailingOnly = FALSE)
  file.arg.name <- "--file="
  script.name <- sub(file.arg.name, "", initial.options[grep(file.arg.name, initial.options)])
  return(script.name[1])
}

.get_options_dict <- function() {
  experiment <- list()

  for(option_name in names(vanguard_settings$parameters)) {

    option <- list(
      type="",
      default=NA
    )

    # TODO currently not supporting lists
    option_value <- vanguard_settings$parameters[[option_name]]
    if(is.numeric(option_value)) {
      option[["type"]] <- "float"
      option[["default"]] <- option_value
    } else if(is.logical(option_value)) {
      option[["type"]] <- "bool"
      option[["default"]] <- option_value
    } else if(is.character(option_value)) {
      option[["type"]] <- "string"
      option[["default"]] <- option_value
    } else {
      option[["type"]] <- "string"
      warning("Unsupported default option value, forcing to string.")
      option[["default"]] <- as.character(option_value)
    }

    experiment[[option_name]] <- option
  }

  return(experiment)
}

.create_experiment <- function() {
  url <- paste0(vanguard_settings$fglab_url,"/api/v1/experiments/create")
  fgmachine_dir <- Sys.getenv("FGMACHINE_DIR")
  experiments_json_loc <- paste0(fgmachine_dir, "/experiments.json")

  if(file.exists(experiments_json_loc)) {
    json_data <- list(project_name=vanguard_settings[["project_name"]],
                      project_description=vanguard_settings[["project_description"]],
                      experiment_name=vanguard_settings[["experiment_name"]],
                      options=.get_options_dict(),
                      tags=vanguard_settings[["tags"]],
                      experiment_setup=experiment_setup,
                      fgmachine_url=Sys.getenv("FGMACHINE_URL")
    )
    response <- POST(url=url, body=json_data, encode="json", verbose())
    experiment_id <- content(response)[["insertedIds"]][[1]]


  } else {
    stop("Could not find FGMachine folder. Please check whether you have entered it correctly in .env file")
  }
}

# ---- Set up connection with FGLab ----
vanguard_init <- function(url, project_name, experiment_name, parameters,
                          filepath, tags=c(), run_locally=FALSE,
                 project_description="-- Project description (legacy) --") {
  settings <- list()
  settings$fglab_url <- url
  settings$project_name <- project_name
  settings$experiment_name <- experiment_name
  settings$parameters <- parameters
  settings$tags <- tags
  settings$run_locally <- run_locally
  settings$project_description <- project_description

  parser <- arg_parser(description="vanguard")
  parser <- add_argument(parser, "--_id", help="id", type="character")
  parser <- add_argument(parser, "--prerun", help="prerun", type="character", nargs=1)
  for(key in names(parameters)) {
    value <- parameters[[key]]
    parser <- add_argument(parser, paste0("--", key), help=key,
                           type=typeof(value))
  }

  args <- parse_args(parser)
  settings$args <- args
  settings$run_id <- args[["_id"]]

  if(is.na(filepath)) {
    stop("File path not specified! Fill out the 'filepath' parameter in vanguard_init().")
  }
  wd <- getwd()

  vanguard_settings <<- settings

  experiment_setup <<- list(
    cwd=wd,
    command="Rscript",
    args=list(paste0(wd, "/", filepath)),
    options="double-dash-space",
    capacity=1,
    results=wd
  )

  if(!is.na(args[["prerun"]]) && args[["prerun"]] == "True") {
    json_data <- list(project_name=settings$project_name,
                      project_description=settings$project_description,
                      experiment_name=settings$experiment_name,
                      options=.get_options_dict(),
                      experiment_setup=experiment_setup,
                      tags=settings$tags)
    cat(toJSON(json_data))
    .stopQuietly()
  } else if(is.na(settings$run_id) && !settings$run_locally) {
    print("Creating new experiment")
    .create_experiment()
    .stopQuietly("Created experiment")
  }
}


#' Sending files
#'
#' Sends an arbitrary file over PUT request to FGLab
#' @param file The filepath

send_file <- function(file){
  mylist <- list()
  myfile <- upload_file(file)
  mylist[['file']] <- myfile
  url <- paste0(vanguard_settings[["fglab_url"]],"/api/v1/runs/", vanguard_settings[["run_id"]], "/file")
  PUT(url, body=mylist)
}

#' Sending files as strings
#'
#' Sends an arbitrary string over PUT request to FGLab into a file
#' @param string The content of the file to be sent
#' @param filename The filename shown on FGLab, including extension

.send_file_as_string <- function(string, filename){
  # Save string to file in a temporary directory
  tdir <- tempdir()
  file_path <- paste0(tdir, "/", filename)
  write(string, file=file_path)

  # Upload file
  myfile <- upload_file(file_path)
  mylist[['file']] <- myfile
  url <- paste0(vanguard_settings[["fglab_url"]],"/api/v1/runs/", vanguard_settings[["run_id"]], "/file")
  PUT(url, body=mylist)
}


#' Sending metrics
#'
#' Sends an arbitrary metric over PUT request to FGLab.
#' @param metric The metric name
#' @value value The metric value

send_metric <- function(metric, value){
  mylist <- list()
  mylist[[metric]] <- value
  json <- list("_scores" = mylist)
  url <- paste0(vanguard_settings[["fglab_url"]],"/api/v1/runs/", vanguard_settings[["run_id"]])
  PUT(url,body=json,encode="json",verbose())
}

#' Sending values
#'
#' Sends an arbitrary value over PUT request to FGLab. Works similarly to send_metric but the results are displayed differently

send_value <- function(name, value){
  mylist <- list()
  mylist[[name]] <- value
  url <- paste0(vanguard_settings[["fglab_url"]],"/api/v1/runs/", vanguard_settings[["run_id"]])
  PUT(url,body=mylist,encode="json",verbose())
}

#' Sending notes
#'
#' Sends arbitrary note over PUT request to FGLab.
#' @param value The string content

send_note <- function(value){
  json <- list("_notes" = value)
  url <- paste0(vanguard_settings[["fglab_url"]],"/api/v1/runs/", vanguard_settings[["run_id"]])
  PUT(url,body=json,encode="json",verbose())
}

#' Sending logs
#'
#' Sends arbitrary log over PUT request to FGLab.
#' @param value The string content

send_log <- function(msg,type="stdout"){
  mylist <- list()
  mylist[["type"]] <- type
  mylist[["msg"]] <- msg
  url <- paste0(vanguard_settings[["fglab_url"]],"/api/v1/runs/", vanguard_settings[["run_id"]], "/logs")
  PUT(url,body=mylist,encode="json",verbose())
}

#' Sending explanations
#'
#' Sends LIME explanation to FGLab
#' @param value The string content TODO

send_explanation <- function(explanation, filename="explanation.png"){
  library(ggplot2)
  g <- plot_features(explanation) # get ggplot object

  # Save plot to file in a temporary directory and send like a normal file
  tdir <- tempdir()
  file_path <- paste0(tdir, "/", filename)
  ggsave(file_path, g)
  send_file(file_path)
}


################# Chart generation

#' Generating time series charts
#'
#' Send an arbitrary number of time series graphs to be displayed in FGLab


send_chart <- function(var_names, values){
  top <- list(columnNames=as.list(var_names))
  mylist <- list()
  mylist[[var_names[1]]] <- "x1"
  mylist[[var_names[2]]] <- "x2"
  #mid <- list(data=list(xs=list(train="x1", val="x2"),columns=values))
  mid <- list(data=list(xs=mylist,columns=values))
  bottom <- list(axis=c(list(x=list(label=list(text="Iterations"))) , list(y=list(label=list(text="Losses")))))
  charts <- list("_charts"=c(top,mid,bottom))
  url <- paste0(vanguard_settings[["fglab_url"]],"/api/v1/runs/", vanguard_settings[["run_id"]])
  PUT(url,body=charts,encode="json")
}

