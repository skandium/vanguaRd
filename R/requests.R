#####################
# Client library in R
#####################

options(warn=-1) # Turn off warnings while loading libraries
options(warn=0)

httr::set_config( httr::config( ssl_verifypeer = 0, ssl_verifyhost=0 ) )

pkg_env <- new.env()

pkg_env$vanguard_settings <- list()
pkg_env$experiment_setup <- list()

unlockBinding("vanguard_settings", pkg_env)
unlockBinding("experiment_setup", pkg_env)

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

  for(option_name in names(pkg_env$vanguard_settings$parameters)) {

    option <- list(
      type="",
      default=NA
    )

    # TODO currently not supporting lists
    option_value <- pkg_env$vanguard_settings$parameters[[option_name]]
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
  url <- paste0(pkg_env$vanguard_settings$fglab_url,"/api/v1/experiments/create")
  fgmachine_dir <- Sys.getenv("FGMACHINE_DIR")
  experiments_json_loc <- paste0(fgmachine_dir, "/experiments.json")

  if(file.exists(experiments_json_loc)) {
    json_data <- list(project_name=pkg_env$vanguard_settings[["project_name"]],
                      project_description=pkg_env$vanguard_settings[["project_description"]],
                      experiment_name=pkg_env$vanguard_settings[["experiment_name"]],
                      options=.get_options_dict(),
                      tags=pkg_env$vanguard_settings[["tags"]],
                      experiment_setup=pkg_env$experiment_setup,
                      fgmachine_url=Sys.getenv("FGMACHINE_URL")
    )
    response <- httr::POST(url=url, body=json_data, encode="json")
    experiment_id <- httr::content(response)[["insertedIds"]][[1]]


  } else {
    stop("Could not find FGMachine folder. Please check whether you have entered it correctly in .env file")
  }
}

#' Connect to FGLab
#'
#' Initialises a connection to FGLab and creates a new experiment
#' @param url The URL of FGLab. Default is likely http://localhost:5080.
#' @param project_name Name of the project on FGLab.
#' @param experiment_name Name of the experiment on FGLab. Must be unique within project.
#' @param parameters A named list of parameters with their default values.
#' @param filepath Path of the file to be run, relative to working directory.
#' @param tags Vector of tags shown on FGLab.
#' @param run_locally If TRUE, execute script locally without going through FGLab.
#'
#' @export

vanguard_init <- function(url, project_name, experiment_name, parameters,
                          filepath, tags=c(), run_locally=FALSE) {
  settings <- list()
  settings$fglab_url <- url
  settings$project_name <- project_name
  settings$experiment_name <- experiment_name
  settings$parameters <- parameters
  settings$tags <- tags
  settings$run_locally <- run_locally
  settings$project_description <- ""

  parser <- argparser::arg_parser(description="vanguard")
  parser <- argparser::add_argument(parser, "--_id", help="id", type="character")
  parser <- argparser::add_argument(parser, "--prerun", help="prerun", type="character", nargs=1)
  for(key in names(parameters)) {
    value <- parameters[[key]]
    parser <- argparser::add_argument(parser, paste0("--", key), help=key,
                           type=typeof(value))
  }

  args <- argparser::parse_args(parser)
  settings$args <- args
  settings$run_id <- args[["_id"]]

  if(is.na(filepath)) {
    stop("File path not specified! Fill out the 'filepath' parameter in vanguard_init().")
  }
  wd <- getwd()

  pkg_env$vanguard_settings <- settings

  pkg_env$experiment_setup <- list(
    cwd=wd,
    command="Rscript",
    args=list(paste0(wd, "/", filepath)),
    options="double-dash-plain",
    capacity=1,
    results=wd
  )

  if(!is.na(args[["prerun"]]) && args[["prerun"]] == "True") {
    json_data <- list(project_name=settings$project_name,
                      project_description=settings$project_description,
                      experiment_name=settings$experiment_name,
                      options=.get_options_dict(),
                      experiment_setup=pkg_env$experiment_setup,
                      tags=settings$tags)
    cat(rjson::toJSON(json_data))
    quit(save="no", status=0) # .stopQuietly
  } else if(is.na(settings$run_id) && !settings$run_locally) {
    print("Creating new experiment")
    .create_experiment()
    .stopQuietly("Created experiment")
  }
}

#' Get an argument value
#'
#' Returns the value of an argument for the given run
#' @param name Name of the argument
#'
#' @export
get_argument <- function(name) {
  return(pkg_env$vanguard_settings$args[[name]])
}


#' Sending files
#'
#' Sends an arbitrary file over PUT request to FGLab
#' @param file The filepath
#'
#' @export

send_file <- function(file){
  mylist <- list()
  myfile <- httr::upload_file(file)
  mylist[['file']] <- myfile
  url <- paste0(pkg_env$vanguard_settings[["fglab_url"]],"/api/v1/runs/", pkg_env$vanguard_settings[["run_id"]], "/file")
  invisible(httr::PUT(url, body=mylist))
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
  myfile <- httr::upload_file(file_path)
  mylist[['file']] <- myfile
  url <- paste0(pkg_env$vanguard_settings[["fglab_url"]],"/api/v1/runs/", pkg_env$vanguard_settings[["run_id"]], "/file")
  invisible(httr::PUT(url, body=mylist))
}


#' Sending metrics
#'
#' Sends an arbitrary metric over PUT request to FGLab.
#' @param metric The metric name
#' @param value The metric value
#'
#' @export

send_metric <- function(metric, value){
  mylist <- list()
  mylist[[metric]] <- value
  json <- list("_scores" = mylist)
  url <- paste0(pkg_env$vanguard_settings[["fglab_url"]],"/api/v1/runs/", pkg_env$vanguard_settings[["run_id"]])
  invisible(httr::PUT(url,body=json,encode="json"))
}

#' Sending values
#'
#' Sends an arbitrary value over PUT request to FGLab. Works similarly to send_metric but the results are displayed differently
#' @param name Name
#' @param value Value
#'
#' @export

send_value <- function(name, value){
  mylist <- list()
  mylist[[name]] <- value
  url <- paste0(pkg_env$vanguard_settings[["fglab_url"]],"/api/v1/runs/", pkg_env$vanguard_settings[["run_id"]])
  invisible(httr::PUT(url,body=mylist,encode="json"))
}

#' Sending notes
#'
#' Sends arbitrary note over PUT request to FGLab.
#' @param value The string content
#'
#' @export

send_note <- function(value){
  json <- list("_notes" = value)
  url <- paste0(pkg_env$vanguard_settings[["fglab_url"]],"/api/v1/runs/", pkg_env$vanguard_settings[["run_id"]])
  invisible(httr::PUT(url,body=json,encode="json"))
}

#' Sending logs
#'
#' Sends arbitrary log over PUT request to FGLab.
#' @param msg Log message
#' @param type Type of outhttr::PUT. Options: "stdout" or "stderr".
#'
#' @export

send_log <- function(msg, type="stdout"){
  mylist <- list()
  mylist[["type"]] <- type
  mylist[["msg"]] <- msg
  url <- paste0(pkg_env$vanguard_settings[["fglab_url"]],"/api/v1/runs/", pkg_env$vanguard_settings[["run_id"]], "/logs")
  invisible(httr::PUT(url,body=mylist,encode="json"))
}

#' Sending explanations
#'
#' Sends LIME explanation to FGLab
#' @param explanation An explanation object returned by LIME.
#' @param filename Filename for explanation in FGLab.
#'
#' @export

send_explanation <- function(explanation, filename="explanation.png"){
  g <- lime::plot_features(explanation) # get ggplot object

  # Save plot to file in a temporary directory and send like a normal file
  tdir <- tempdir()
  file_path <- paste0(tdir, "/", filename)
  ggplot2::ggsave(file_path, g)
  invisible(send_file(file_path))
}


################# Chart generation

#' Generating time series charts
#'
#' Send an arbitrary number of time series graphs to be displayed in FGLab
#' @param var_names ?
#' @param values ?
#'
#' @export

send_chart <- function(var_names, values){
  top <- list(columnNames=as.list(var_names))
  mylist <- list()
  mylist[[var_names[1]]] <- "x1"
  mylist[[var_names[2]]] <- "x2"
  #mid <- list(data=list(xs=list(train="x1", val="x2"),columns=values))
  mid <- list(data=list(xs=mylist,columns=values))
  bottom <- list(axis=c(list(x=list(label=list(text="Iterations"))) , list(y=list(label=list(text="Losses")))))
  charts <- list("_charts"=c(top,mid,bottom))
  url <- paste0(pkg_env$vanguard_settings[["fglab_url"]],"/api/v1/runs/", pkg_env$vanguard_settings[["run_id"]])
  invisible(httr::PUT(url,body=charts,encode="json"))
}

