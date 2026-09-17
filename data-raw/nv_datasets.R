# Build the curated dataset-facts table backing the `dataset` tool.
# Tier-3 tacit knowledge: id conventions, coord space, auth, quirks.
# Ends with usethis::use_data(nv_datasets, overwrite = TRUE) once populated.
#
# Schema (one row per dataset):
#   id, aliases, organism, region, id_type, stable_handle,
#   coord_space, voxel_nm, auth, neuropil_convention, access_via, quirks

library(tibble)

nv_datasets <- tribble(
  ~id,         ~organism,            ~region,        ~id_type,     ~stable_handle, ~auth,      ~access_via,     ~quirks,
  "hemibrain", "Drosophila (female)", "central brain","bodyid",     "bodyid",       "neuprint", "neuprintr",     "Static release; bodyids stable within a version.",
  "flywire",   "Drosophila (female)", "whole brain",  "rootid",     "supervoxel",   "cave",     "fafbseg",       "Root ids drift with proofreading; pin by supervoxel or raw xyz.",
  "malecns",   "Drosophila (male)",   "CNS",          "bodyid",     "bodyid",       "neuprint", "malecns",       "In progress; typing evolving.",
  "manc",      "Drosophila (male)",   "VNC",          "bodyid",     "bodyid",       "neuprint", "malevnc",       "Male adult nerve cord.",
  "banc",      "Drosophila (female)", "brain + VNC",  "rootid",     "supervoxel",   "cave",     "bancr",         "CAVE datastack; cell typing in a CAVE table, not on the neuron."
)

usethis::use_data(nv_datasets, overwrite = TRUE)
