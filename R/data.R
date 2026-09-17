#' Curated natverse dataset facts
#'
#' A small, hand-curated table of connectome dataset ground truth backing the
#' `dataset` tool: id conventions, coordinate space, authentication and the
#' quirks an agent must know to write correct code (e.g. that FlyWire root ids
#' drift with proofreading). This is Tier-3 tacit knowledge, written once and
#' folded into the served index by [build_index()].
#'
#' @format A data frame with one row per dataset and columns:
#' \describe{
#'   \item{id}{Canonical short dataset name (e.g. `"flywire"`).}
#'   \item{organism}{Species and sex.}
#'   \item{region}{Nervous-system region covered.}
#'   \item{id_type}{The neuron identifier type (`bodyid`, `rootid`).}
#'   \item{stable_handle}{Stable handle to pin a neuron by (e.g. supervoxel).}
#'   \item{auth}{Authentication backend (`neuprint`, `cave`).}
#'   \item{access_via}{natverse package used to access the dataset.}
#'   \item{quirks}{Free-text gotchas an agent should know.}
#' }
#' @source Curated by the natverse maintainers; see `data-raw/nv_datasets.R`.
"nv_datasets"
