#' Run rodeo-based model in shiny GUI
#'
#' Runs a rodeo-based model in a shiny GUI to allow for variation of parameters
#' and/or initial values.
#'
#' @inheritParams initModel
#' @param obs If not \code{NULL}, this must be a data frame with observed values
#'   of the state variables. Time information (numeric) is expected in the first
#'   column. Columns with observation data (if existing) must be named like the
#'   simulated state variables. Missing values must be marked as \code{NA}.
#' @param serverMode Defaults to \code{FALSE}. If set to \code{TRUE}, data
#'   required by the GUI are saved to disk only (and the shiny app is
#'   \emph{not} run).
#'
#' @return \code{NULL} if \code{serverMode} is \code{FALSE} or the
#'   path/name of the created data file if \code{serverMode} is \code{TRUE}.
#'
#' @note The function exports variables to the global environment for
#'   use by the shiny server and user interface.
#'
#' @author David Kneis \email{david.kneis@@tu-dresden.de}
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   library(rodeoApp)
#'   runGUI(dir=system.file("examples/DRT", package="rodeoApp"))
#' }

runGUI= function(
  dir="", xlFile="model.xlsx", funsR="functions.r", funsF="functions.f95",
  tables= c(vars="vars",pars="pars",funs="funs",pros="pros",stoi="stoi"),
  colsep=",", obs=NULL, serverMode=FALSE
) {
  dir= normalizePath(dir, winslash="/")

  # Run init
  ini= initModel(dir=dir, xlFile=xlFile, funsR=funsR, funsF=funsF,
    tables=tables, colsep=colsep)

  if (serverMode) {
    dirSettings= "."  # button to save files not available anyway
  } else {
    if (as.integer(file.access(dir, mode = 2)) == 0) {
      dirSettings= dir           # if model folder is writeable
    } else {
      dirSettings= getwd()       # otherwise
    }
  }

  # Save data to file (to be loaded in server/ui)
  rodeoAppData= list(
    model= ini$model,
    dllfile= ifelse(serverMode, basename(ini$dllfile), ini$dllfile),
    funsR= ifelse(serverMode, basename(ini$funsR), ini$funsR),
    vars= ini$vars,
    pars= ini$pars,
    obs= obs,
    wd= ifelse(serverMode,".",getwd()),
    fileSettings= paste0(dirSettings,"/rodeoApp.savedSettings"),
    serverMode=serverMode
  )
  # NOTE: File/path name must be consistent with server/ui
  rodeoAppDataFile= paste0(gsub(pattern="\\", replacement="/", x=tempdir(),
    fixed=TRUE), "/rodeoAppData.rda")
  save(rodeoAppData, file=rodeoAppDataFile, ascii=TRUE)
  rm(rodeoAppData)

  # Start shiny app
  if (serverMode) {
    return(rodeoAppDataFile)
  } else {
    shiny::runApp(system.file("shiny", package="rodeoApp"))
    return(invisible(NULL))
  }
}


################################################################################
#' Run rodeo-based model in Monte Carlo mode
#'
#' Runs a rodeo-based model in Monte Carlo mode with parameters and initial
#' values sampled from uniform distributions (latin hypercube method).
#'
#' @inheritParams runGUI
#' @param outdir Output directory. Should be empty unless \code{overwrite} is \code{TRUE}.
#' @param times Vector of times for which the states are computed.
#' @param nruns Desired number of model runs.
#' @param nsig Number of significant digits in output files. Should be set to
#'   a reasonably small value for large \code{nruns} in order to save disk space.
#' @param overwrite Logical. Is it OK to overwrite existing output files?
#' @param silent Logical. Used to switch diagnostic messages on/off.
#'
#' @return \code{NULL}, see notes
#'
#' @note The function creates three TAB-separated text files in \code{outdir}:
#' \itemize{
#'   \item{\code{var.txt} : } Initial values of state variables (one record for
#'     each run).
#'   \item{\code{par.txt} : } Parameters (one record for each run).
#'   \item{\code{sim.txt} : } Simulation results. For each run, the number of
#'     records equals the number of elements in \code{times}.
#' }
#' The first column in all these tables is named 'runID'. It is the primary
#' key column to be used when merging the tables, e.g. using \code{\link{merge}}.
#'
#' @author David Kneis \email{david.kneis@@tu-dresden.de}
#'
#' @export
#'
#' @examples
#' \dontrun{
#'   library(rodeoApp)
#'   runMCS(
#'     outdir=gsub(pattern="\\", replacement="/", x=tempdir(), fixed=TRUE),
#'     times=seq(0,30,1/24), nruns=10, nsig=4, overwrite=FALSE,
#'     dir=system.file("examples/DRT", package="rodeoApp"))
#' }

runMCS= function(
  outdir,
  times,
  nruns,
  nsig=4,
  overwrite=FALSE,
  dir="", xlFile="model.xlsx", funsR="functions.r", funsF="functions.f95",
  tables= c(vars="vars",pars="pars",funs="funs",pros="pros",stoi="stoi"),
  colsep=",",
  silent=FALSE
) {
  dir= normalizePath(dir, winslash="/")
  # Initialize model
  ini= initModel(dir=dir, xlFile=xlFile, funsR=funsR, funsF=funsF,
    tables=tables, colsep=colsep)
  # Set/check output files
  outfiles= c(var="var.txt", par="par.txt", sim="sim.txt")
  outfiles= setNames(paste(outdir, outfiles, sep="/"), names(outfiles))
  if ((any(file.exists(outfiles))) && (!overwrite))
    stop("output file(s) already exist, overwriting not permitted")
  # Sampling ranges
  required= c("name","lower","upper")
  if (!all(required %in% names(ini$pars)))
    stop(paste0("incomplete table of parameters; the required columns are: '",
      paste(required,collapse="', '"),"'"))
  if (!all(required %in% names(ini$vars)))
    stop(paste0("incomplete table of variables; the required columns are: '",
      paste(required,collapse="', '"),"'"))
  # Sample initial values
  tmp= improvedLHS(n=nruns, k=nrow(ini$vars))
  colnames(tmp)= ini$vars$name
  v= as.data.frame(tmp)
  for (i in 1:nrow(ini$vars)) {
    v[,i]= ini$vars[i,"lower"] + v[,i] * (ini$vars[i,"upper"] - ini$vars[i,"lower"])
  }
  write.table(x=cbind(runID=1:nruns, v), file=outfiles["var"],
    sep="\t", col.names=TRUE, row.names=FALSE, quote=FALSE)
  # Sample parameters
  tmp= improvedLHS(n=nruns, k=nrow(ini$pars))
  colnames(tmp)= ini$pars$name
  p= as.data.frame(tmp)
  for (i in 1:nrow(ini$pars)) {
    p[,i]= ini$pars[i,"lower"] + p[,i] * (ini$pars[i,"upper"] - ini$pars[i,"lower"])
  }
  write.table(x=cbind(runID=1:nruns, p), file=outfiles["par"],
    sep="\t", col.names=TRUE, row.names=FALSE, quote=FALSE)
  # Simulations
  for (i in 1:nruns) {
    if (!silent)
      cat("run",i,"of",nruns,"\n")
    tmp= simul(model=ini$model,
      vars=setNames(unlist(v[i,]),names(v)),
      pars=setNames(unlist(p[i,]),names(p)),
      times=times, dllfile=ini$dllfile)
    colnames(tmp)= c("time", ini$model$namesVars(), ini$model$namesPros())
    tmp[,2:ncol(tmp)]= signif(tmp[,2:ncol(tmp)], nsig)
    tmp= cbind(runID=i, tmp)
    write.table(x=tmp, file=outfiles["sim"],
      sep="\t", col.names=(i==1), row.names=FALSE, quote=FALSE, append=(i>1))
  }
  return(invisible(NULL))
}


