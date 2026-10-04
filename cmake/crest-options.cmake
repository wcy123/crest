##
# cmake/crest-options.cmake — All user-visible CREST configuration options
#
# Include this file before cmake/build_options.cmake and cmake/deps.cmake.
# Downstream projects that embed crest via add_subdirectory() can override
# any option BEFORE the add_subdirectory() call:
#
#   set(CREST_WARNINGS_AS_ERRORS OFF)
#   set(CREST_EMBED_SCHEME_BOOT  ON)
#   list(PREPEND CREST_BOOT_SOURCE_DIRS "${MY_SCHEME_DIR}")
#   list(PREPEND CREST_BOOT_ROOTS       "${MY_SCHEME_DIR}/my-pass.sls")
#   add_subdirectory(crest)
##

# ─── Compiler warnings ────────────────────────────────────────────────────────
option(CREST_WARNINGS_AS_ERRORS
  "Treat compiler warnings as errors (-Werror / /WX)"
  ON)

# ─── Scheme boot embedding ────────────────────────────────────────────────────
# When ON, all .sls libraries are compiled into a single crest.boot and
# embedded as a C byte-array. The interpreter loads it at startup so no
# .sls files are needed at deployment time.
# When OFF (default), the interpreter searches for .sls files at runtime
# via addLibraryPath — convenient during development.
option(CREST_EMBED_SCHEME_BOOT
  "Compile and embed Scheme libraries into the binary (deployment)"
  OFF)

# ─── Boot compilation: extensible source dirs and root libraries ──────────────
# These list variables let downstream projects add their own Scheme libraries
# to the boot file.  CREST appends its own entries in cmake/deps.cmake, so
# downstream entries set here (via PREPEND) take precedence in the search order.
#
# CREST_BOOT_SOURCE_DIRS: directories containing .sls source files.
#   Each dir is paired with the shared obj-dir in library-directories.
#
# CREST_BOOT_ROOTS: absolute paths to root .sls files.
#   Each root triggers recursive compilation of all its transitive imports.
set(CREST_BOOT_SOURCE_DIRS "" CACHE STRING
  "Additional Scheme source directories to include in crest.boot")

set(CREST_BOOT_ROOTS "" CACHE STRING
  "Additional root .sls files whose transitive imports are compiled into crest.boot")
