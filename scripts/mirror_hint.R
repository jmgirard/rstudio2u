## rstudio2u: friendly hint when a package install fails because the r2u
## binary mirror is unreachable (Known issue #1).
##
## bspm installs r-cran-* binaries via apt from the r2u mirror, which is
## occasionally down through no fault of the image; a raw wall of apt error
## text is opaque to a classroom user. This wraps install.packages() so that,
## *only* when requested packages remain uninstalled AND an apt mirror looks
## unreachable, a plain-language hint is printed. The original behaviour and
## any error/warning are preserved unchanged — the hint is purely additive.
##
## The outage is detected by a direct TCP reachability probe of the configured
## apt mirrors, not by matching apt's error text: text matching is brittle and
## cannot tell a transient outage from an ordinary "package does not exist"
## error, whereas the probe distinguishes them (a missing-but-mirror-reachable
## install never fires the hint).
##
## Appended to /etc/R/Rprofile.site after bspm::enable() so `install.packages`
## already resolves to bspm's binary installer when we capture it.

local({
  ## Every http(s) mirror host referenced by apt's sources.
  mirror_urls <- function() {
    files <- c(list.files("/etc/apt/sources.list.d", full.names = TRUE),
               "/etc/apt/sources.list")
    files <- files[file.exists(files)]
    if (!length(files)) return(character(0))
    txt <- unlist(lapply(files, readLines, warn = FALSE))
    unique(unlist(regmatches(txt, gregexpr("https?://[^[:space:]/]+", txt))))
  }

  ## TRUE if a raw TCP connection to the mirror's host:port opens.
  reachable <- function(u) {
    host <- sub("^https?://", "", u)
    port <- if (startsWith(u, "https")) 443L else 80L
    con <- tryCatch(
      socketConnection(host, port, open = "r+", blocking = TRUE, timeout = 5),
      error = function(e) NULL, warning = function(w) NULL)
    if (is.null(con)) return(FALSE)
    close(con)
    TRUE
  }

  ## Only report an outage on a positive failure; unknown (no mirrors found)
  ## stays FALSE so we never cry outage on a false alarm.
  mirror_unreachable <- function() {
    us <- mirror_urls()
    if (!length(us)) return(FALSE)
    any(!vapply(us, reachable, logical(1)))
  }

  hint <- function() {
    bar <- strrep("-", 64)
    message(bar)
    message("rstudio2u: the r2u package mirror looks unreachable.")
    message("This is almost always a temporary network or mirror outage,")
    message("not a problem with your code or this container.")
    message("Wait a minute and run install.packages(...) again.")
    message(bar)
  }

  ## bspm's install.packages, captured now that bspm::enable() has run.
  prev <- get("install.packages")

  wrapper <- function(pkgs, ...) {
    diagnose <- function() {
      if (is.character(pkgs) && length(pkgs)) {
        missing <- pkgs[!(pkgs %in% rownames(installed.packages()))]
        if (length(missing) && mirror_unreachable()) hint()
      }
    }
    ## bspm may error, warn, or silently fall back to source; diagnose the
    ## post-state in every case, and always re-raise the original error.
    tryCatch(prev(pkgs, ...), error = function(e) { diagnose(); stop(e) })
    diagnose()
    invisible()
  }

  e <- new.env()
  e$install.packages <- wrapper
  ## Shadow bspm's install.packages from a front-of-search-path environment so
  ## interactive and script calls hit the wrapper; explicit utils::/bspm::
  ## qualified calls still reach the underlying installer unchanged.
  attach(e, name = "rstudio2u:mirror-hint", warn.conflicts = FALSE)
})
