# Stereo-seq: GEF and cellbin files

BGI/MGI **Stereo-seq** spatial transcriptomics runs, processed with the vendor's
**SAW** pipeline, produce two files NDR reads. Both are HDF5, and neither is
epoch-based data, so neither has an `ndr.reader` class:

| file | holds | function |
| ---- | ----- | -------- |
| `.gef` | one record per (pixel, gene) pair for a whole section | `ndr.format.stereoseq.readGEF` |
| cellbin `.h5ad` | segmented cells: centroids, boundaries, per-cell measurements, labels | `ndr.format.stereoseq.readCellBin` |

They sit in `+ndr/+format/` rather than `+ndr/+reader/` deliberately. A section
is not a time series; it would be a single epoch only by force, and SAW carries
far more parameters than the reader interface has room for. NDR reads the
vendor's file and returns arrays; turning those into documents is NDI's job
(`ndi.fun.doc.gene.makePyramid`, `makeCells`, `makeCellTypeLabels`).

Scale matters when reading this code. A real section is ~30,000 genes and
~10^8 records, and the pyramid built from one is several GB. Both functions
therefore take `probeOnly`, which reports what a file contains -- gene count,
extent, chip serial, available columns -- without reading the bulk data, so a
caller can show a file before committing minutes to it.

## Nothing about the GEF layout is assumed

Layouts drift between SAW versions, so every path and field name is probed
against a candidate list rather than hard-coded:

- records live under `/geneExp/bin1` **or** `/wholeExp/bin1`
- the expression dataset is `expression` **or** `cellBin`
- coordinates are `x`/`y` **or** `X`/`Y`
- the count field is `count`, `MIDCount`, `mid_count` **or** `umi`

A reader that hard-codes one spelling works on the file it was written against
and fails on the next with an error naming nothing useful.

### Gene blocks are not always in gene order

`/geneExp/bin1/gene` carries an `offset` and `count` per gene, delimiting that
gene's block of expression records. When the offsets are contiguous and
ascending the whole dataset can be read in a few large blocks; when they are
not, each gene must be read separately. `readGEF` checks which case it is
rather than assuming, because one read per gene is ~26,000 HDF5 calls on a real
file and the per-call overhead dominates.

Records come back in **gene order**, which for a non-contiguous file is not the
order they appear in on disk.

### The extent attributes are trusted only when they contain the data

SAW writes `minX`/`maxX`/`minY`/`maxY` as HDF5 attributes, but **where** varies:
on the bin group, on an ancestor, or at the file root. All are probed,
nearest-first. An attribute box that does not enclose the actual coordinates is
rejected in favour of the data, which cannot be wrong about its own extent.

Probing only the file root yields a 1x1 pyramid on files that put the
attributes deeper. That bug is easy to write and easy to miss: a synthetic
fixture that happens to write them at the root agrees with it.

### Counts are clipped in a wide type

SAW writes **uint8** counts at bin1. Clipping in the narrow type saturates every
value at 255 rather than at the intended ceiling, silently. `readGEF` casts to
a wide type first and reports how many values were clamped.

## The cellbin file does not say what its contours mean

An `.h5ad` is HDF5 with [AnnData](https://anndata.readthedocs.io) conventions on
top, and NDR reads it with plain HDF5 rather than through the `anndata` library,
so MATLAB and Python do the same thing. The conventions that matter:

- `/obs` carries an `_index` attribute naming the identifier dataset
- numeric columns of `/obs` are datasets
- **categorical columns are groups** holding `categories` and `codes`
- variable-length strings come back from MATLAB's `h5read` as a **string array**,
  not a cell or char matrix

Cell boundaries live in `obsm/cell_border`, shaped (cells, vertex slots, 2) with
unused slots padded. Two things about them are **not recorded anywhere in the
file** and must be inferred:

1. what value pads the unused slots (32767 on the sections seen so far)
2. whether vertices are stored **relative to each cell's centroid** or in
   absolute source coordinates

Getting the second wrong is silent and total: treat absolute vertices as
relative and every outline lands a chip-width away from its cell, with no error
raised. So `readCellBin` reports rather than deciding quietly --
`meta.contourReference` is the answer, `meta.contourReferenceSource` says whether
it was detected or forced by the caller, and `meta.relativeEvidence` carries the
numbers behind it. Both can be overridden.

The rule: vertices are centroid-relative when the median magnitude of the **real**
(non-padding) vertices is under 5% of the centroid scale, where the scale is
`max(max|x|, max|y|, 1)`. Padding is excluded first, or a sentinel of 32767 would
dominate the median and mask small relative offsets.

An empty contour keeps its row rather than being dropped. Dropping it would
shift every later cell's boundary onto the wrong cell.

## Label columns are reported, not chosen

A cellbin routinely carries several labelings side by side -- a cell type call
transferred from a dissociated atlas, and one or more unsupervised clusterings.
They are **not interchangeable**: a clustering carries no biological identity,
so cluster 3 is an index and not a cell type, and it means nothing outside the
run that produced it.

The file does not distinguish them. `readCellBin` lists every categorical column
with an `isUnsupervisedGuess` flag derived from the column **name** alone
(`leiden`, `louvain`, `snn_res`, `cluster*`) and marks it as a guess, because
that is all the file supports. NDI's `cellTypeLabels` document has an
`is_unsupervised` field for a human to settle, and
`ndi.fun.doc.gene.makeCellTypeLabels` defaults it to the safer assumption.

Reading a cluster index as a cell type is a scientific error, not a display bug,
which is why the uncertainty is carried explicitly rather than resolved by a
heuristic nobody sees.

## Conformance fixtures

Both functions are tested against small synthetic files generated by
`bscholl-genomics-python/cloudFriendly/make_gef_conformance_fixtures.py` and
`make_cellbin_conformance_fixtures.py`, which write byte-identical copies into
NDR-matlab and NDR-python so the two ports are held to the same artifacts.

The `.gef` fixtures are written with `h5py` and the `.h5ad` fixtures with the
real `anndata` library -- deliberately not by MATLAB. A reader whose job is
coping with files it did not write proves little against one it wrote itself,
and if `anndata` changes how it lays out categoricals or the obs index, the
tests fail and say so.

Each fixture varies exactly one probed thing, so a failure names the probe that
broke rather than reporting that a file would not read.
