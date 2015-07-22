#' Run a dynamic simulation
#'
#' Computes the values of the state variables for a sequence of times.
#'
#' @param model Object of class \code{rodeo} representing the model.
#' @param vars Named vector of the state variables' initial values.
#' @param pars Named vector of parameters.
#' @param times Vector of times for which the states are computed.
#' @param dllfile Shared library file holding the compiled model.
#' @param rtol Vector of the same length as \code{vars} specifying the
#'   relative tolerance for the solver (see help of \code{deSolve::lsoda}).
#' @param atol Vector of the same length as \code{vars} specifying the
#'   absolute tolerance for the solver (see help of \code{deSolve::lsoda}).
#'
#' @return The object returned by \code{deSolve::ode}.
#'
#' @note An error is generated if the integration was not successful.
#'
#' @author David Kneis \email{david.kneis@@tu-dresden.de}
#'
#' @export
simul= function(model, vars, pars, times, dllfile, rtol, atol) {
  # Transform input data
  vars= model$arrangeVars(as.list(vars))
  pars= model$arrangePars(as.list(pars))
  # Also arrange the tolerances
  rtol= model$arrangeVars(as.list(rtol))
  atol= model$arrangeVars(as.list(atol))
  # Load library
  ext= substr(.Platform$dynlib.ext, 2, nchar(.Platform$dynlib.ext))
  dllname= sub(pattern=paste0("(.+)[.]",ext,"$"),replacement="\\1",
    x=basename(dllfile))
  dyn.load(dllfile)
  # Integrate
  out= deSolve::ode(y=vars, times=times, func="derivs_wrapped", rtol=rtol, atol=atol, dllname=dllname,
    initfunc="initmod", nout=model$lenPros(), outnames=model$namesPros(), parms=pars)
  if (attr(out,which="istate",exact=TRUE)[1] != 2)
    stop(paste0("Integration failed.\n----- The initial values were:\n",
      paste(names(vars),vars,sep="=",collapse="\n"),"\n----- The parameters were:\n",
      paste(names(pars),pars,sep="=",collapse="\n")
    ))
  # Clean up and return
  dyn.unload(dllfile)
  return(out)
}

#' Compute steady-state solution
#'
#' Estimates the values of the state variables for steady-state conditions.
#'
#' @inheritParams simul
#'
#' @return The object returned by \code{rootSolve::steady}. The \code{y}-
#'   component of this object has names based on the \code{ynames}
#'   attribute.
#'
#' @note An error is generated if steady-state estimation was not successful.
#'
#' @author David Kneis \email{david.kneis@@tu-dresden.de}
#'
#' @export
stst= function(model, vars, pars, dllfile, rtol, atol) {
  # Transform input data
  vars= model$arrangeVars(as.list(vars))
  pars= model$arrangePars(as.list(pars))
  # Also arrange the tolerances
  rtol= model$arrangeVars(as.list(rtol))
  atol= model$arrangeVars(as.list(atol))
  # Load library
  ext= substr(.Platform$dynlib.ext, 2, nchar(.Platform$dynlib.ext))
  dllname= sub(pattern=paste0("(.+)[.]",ext,"$"),replacement="\\1",
    x=basename(dllfile))
  dyn.load(dllfile)
  # Compute steady state solution
  out= rootSolve::steady(y=vars, time=NULL, func="derivs_wrapped", parms=pars,
    method="runsteady", dllname=dllname, initfunc="initmod",
    nout=model$lenPros(), outnames=model$namesPros())
  if (!attr(out, which="steady",exact=TRUE))
    stop(paste0("Steady-state estimation failed.\n----- The initial values were:\n",
      paste(names(vars),vars,sep="=",collapse="\n"),"\n----- The parameters were:\n",
      paste(names(pars),pars,sep="=",collapse="\n")
    ))
  names(out$y)= attr(out, which="ynames",exact=TRUE)
  # Clean up and return
  dyn.unload(dllfile)
  return(out)
}

