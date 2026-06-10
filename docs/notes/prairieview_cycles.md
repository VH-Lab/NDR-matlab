# PrairieView recordings: cycles and epochs

Two-photon recordings made with Prairie Technologies' **PrairieView** software
are organized into **cycles**. A single recording (a "run", e.g. a directory
named `t00012-001`) contains one or more cycles, and each cycle is a contiguous
block of acquired frames:

- Frame image files are named with the cycle and a per-cycle frame index that
  **resets at the start of each cycle**, e.g.
  `t00012-001_Cycle001_..._Ch1_000001.tif`,
  `t00012-001_Cycle002_..._Ch1_000001.tif` ... `..._Ch1_000020.tif`,
  `t00012-001_Cycle003_..._Ch1_000001.tif`.
- The run's `*_Main.pcf` (older recordings) or `*.xml` (PVScan) config records,
  among other things, the number of cycles, the number of images in each cycle,
  and an `[Image TimeStamp (us)]` (or per-`<Frame>` time) list with **one
  timestamp per frame across all cycles**, in acquisition order.

For example, a real `t00012-001_Main.pcf` declares `Total cycles=3`,
`Total images=22`, cycle image counts of `1`, `20`, `1`, and a 22-entry
`[Image TimeStamp (us)]` list.

## How NDR reads cycles

`ndr.reader.prairieview` reads a **collection of cycles as a single epoch**.
That is, one Prairie run directory corresponds to **one NDR (and NDI) epoch**,
regardless of how many cycles it contains:

- `framelayout` enumerates the frames across **all** cycles and orders them
  **cycle-then-frame**, so timepoint 1 is the first frame of cycle 1, then the
  frames of cycle 2, and so on. Channels (`Ch1`, `Ch2`, ...) of a timepoint are
  grouped onto the image's channel (C) axis; a "frame" is one timepoint.
- `frametimes` / `epochclock` / `t0_t1` use the Main config's per-frame
  timestamp list, which already spans every cycle, so the timestamps line up
  one-to-one with the cycle-then-frame timepoint order. The epoch clock is
  `dev_local_time`, and the real (possibly irregular, with gaps between cycles)
  per-frame times are preserved.

The number of frames the epoch exposes (`numframes`) therefore equals the
config's `Total images` (the sum of the per-cycle image counts).

## If you need one epoch per cycle

The default — one epoch per run (all cycles together) — matches how these
recordings are typically analyzed. Splitting a run so that **each cycle is its
own epoch** is a file-navigator decision on the NDI side (which files comprise
an epoch). It would also require selecting the per-cycle slice of the Main
timestamp list for each cycle's frames. That is not implemented in the reader
today; the reader treats whatever frame files it is handed for an epoch as a
single ordered, cycle-then-frame stack.
