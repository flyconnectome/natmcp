# natverse guide (orientation map)

This file is the hand-authored, Tier-3 backbone of the `guide` tool: the
altitude map an agent needs *before* it can search sensibly. Keep it short and
outcome-focused; per-function detail comes from `signature`/`find`.

The natverse is a toolbox for combining and analysing neuroanatomical data,
introduced in Bates, Manton, et al. (2020), *The natverse, a versatile toolbox
for combining and analysing neuroanatomical data*, eLife 9:e53350
(<https://doi.org/10.7554/eLife.53350>). That paper is the best single
introduction to natverse organisation and philosophy. Connectome analysis has
moved on substantially since 2020 — mostly through `coconatfly` and the dataset
access packages below — so treat the paper as orientation, not current API.

## What altitude to reach for

Reach for the *highest* layer that answers the question:

- **Cross-dataset connectome analysis → `coconatfly` (`cf_*`).** This is the
  most generic way to run connectome analyses: fetch neurons and connectivity by
  cell type or query across datasets (hemibrain, FlyWire, male CNS, MANC, BANC)
  behind one uniform interface, and cosine-cluster or compare them. Start here
  for "who connects to whom", "compare this cell type across brains", partner
  and cosine analyses. Its vignettes are the strong, current overview of this
  workflow.
- **One specific dataset → its access package** (`neuprintr`, `fafbseg`,
  `malecns`, `malevnc`, `bancr`, `fancr`). Drop to these when you need
  dataset-specific queries, metadata, segmentation/mesh access or auth that
  `coconatfly` does not surface.
- **Neuron/image geometry → `nat` (core).** Low-level data structures and
  operations (read/plot/transform/prune neurons and skeletons, spatial
  queries). Reach here for manipulation below the connectivity layer.
- **Registration / bridging between template brains → `nat.templatebrains` +
  `nat.flybrains`.** Move points, neurons and surfaces between template spaces.
- **Meshes → `Rvcg` / `Morpho` / `rgl`** (see below).

## Package roles

Tier-A natverse core and clients:

- **`nat`** — foundational data structures and operations for neurons, skeletons
  and 3D image data. Its vignettes are the high-quality overview of the key data
  structures and concepts; read them to understand `neuron`/`neuronlist`,
  coordinates and spatial operations before anything higher up.
- **`coconatfly`** — the generic cross-dataset connectome layer (`cf_*`). Most
  analyses should enter here. Strong vignettes cover the standard workflows.
- **`neuprintr`** — client for neuPrint servers (e.g. hemibrain, MANC).
- **`fafbseg`** — FlyWire / FAFB segmentation, meshes, connectivity and id
  handling.
- **`malecns`, `malevnc`, `bancr`, `fancr`** — access packages for the male CNS,
  male VNC, BANC and FANC datasets.
- **`nat.templatebrains`** — machinery for registration and bridging between
  template brains; a key reference for transforms.
- **`nat.flybrains`** — the concrete fly template brains and bridging registrations
  used with `nat.templatebrains`.

Tier-B adjacent foundations (mesh + graph interop):

- **`Rvcg`, `Morpho`, `rgl`** — mesh manipulation and 3D visualisation. Important
  for **both** neurons and brain regions: smoothing, remeshing, decimation,
  distances, and interactive/`rgl` rendering of surfaces and neurons.
- **`igraph`** — graph representation and algorithms behind neuron skeletons and
  connectivity networks.

## Dataset roster

The `dataset` tool serves curated per-dataset facts (id conventions, coordinate
space, authentication, quirks such as FlyWire root-id drift) from the
`nv_datasets` table. Ask it by dataset id/alias (e.g. `flywire`, `hemibrain`,
`malecns`, `manc`, `banc`) before writing dataset-specific code.

## How the pieces compose

Typical pipelines, highest layer first:

- **Connectivity:** cell-type/query → `coconatfly::cf_ids()` → partners /
  connectivity → cosine comparison across datasets. Stay in `cf_*` unless you
  need something only a dataset client exposes.
- **Neuron → mesh → view:** neuron or segment id → dataset client for
  skeleton/mesh → `Rvcg`/`Morpho` to process the mesh → `rgl` to render.
- **Bridging:** neurons/points in one template space → `nat.templatebrains`
  (with `nat.flybrains` registrations) → target space, then plot or compare.
- **Graph:** neuron skeleton or connectivity → `igraph` for paths, components
  and centrality.
