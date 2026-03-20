# Neuropixels SpikeGLX Format — NDR Design Document

## Overview

This document describes the NDR support for Neuropixels data acquired with
[SpikeGLX](https://billkarsh.github.io/SpikeGLX/), the open-source acquisition
software for Neuropixels probes developed by Bill Karsh at the Allen Institute.

## File Organization

SpikeGLX saves data in a directory structure organized by run name, gate index,
and trigger index. Each imec probe stream gets its own subdirectory:

```
runname_g0/                          # Gate 0
  runname_g0_imec0/                  # Probe 0 subdirectory
    runname_g0_t0.imec0.ap.bin       # AP-band binary data
    runname_g0_t0.imec0.ap.meta      # AP-band metadata
    runname_g0_t0.imec0.lf.bin       # LF-band binary data (Neuropixels 1.0)
    runname_g0_t0.imec0.lf.meta      # LF-band metadata
  runname_g0_imec1/                  # Probe 1 subdirectory (if multi-probe)
    runname_g0_t0.imec1.ap.bin
    runname_g0_t0.imec1.ap.meta
    ...
  runname_g0_t0.nidq.bin             # NI-DAQ auxiliary I/O (optional)
  runname_g0_t0.nidq.meta
```

### Naming convention

- **`_g<N>`** — Gate index (typically 0). Gates control when acquisition runs.
- **`_t<N>`** — Trigger index (typically 0). Triggers segment data within a gate.
- **`.imec<N>`** — Probe index (0-based). Each probe has independent clocks.
- **`.ap`** — Action potential band (~30 kHz, high-pass filtered on-probe).
- **`.lf`** — Local field potential band (~2.5 kHz, low-pass filtered). Only
  available on Neuropixels 1.0 probes; Neuropixels 2.0 saves only AP data.

## Binary File Format (.bin)

The `.bin` files contain raw data as **interleaved int16** values with **no
header**. Each time sample consists of one int16 value per saved channel,
written consecutively:

```
[ch0_t0 ch1_t0 ch2_t0 ... chN_t0] [ch0_t1 ch1_t1 ... chN_t1] ...
```

- Data type: **int16** (signed 16-bit integer), little-endian
- Byte order: **ieee-le** (Intel byte order)
- No file header — the file begins immediately with sample data
- Total samples = `fileSizeBytes / (nSavedChans * 2)`

### Sync channel

The last channel in each binary file is a **sync channel** (digital word).
For a standard 384-channel Neuropixels 1.0 AP recording, the file contains
385 channels: 384 neural + 1 sync.

## Metadata File Format (.meta)

Each `.bin` file has a companion `.meta` file containing acquisition
parameters as `key=value` pairs, one per line.

### Critical fields

| Field               | Description                                        | Example          |
|---------------------|----------------------------------------------------|------------------|
| `imSampRate`        | Sampling rate in Hz                                | `30000`          |
| `nSavedChans`       | Total channels per sample (neural + sync)          | `385`            |
| `snsSaveChanSubset` | Which channels were saved (`all` or `0:383,768`)   | `all`            |
| `snsApLfSy`         | Count of AP, LF, and sync channels                 | `384,0,1`        |
| `fileSizeBytes`     | Size of the binary file in bytes                   | `231000000`      |
| `fileTimeSecs`      | Duration of the recording in seconds               | `300.0`          |
| `imAiRangeMax`      | Maximum voltage of ADC input range (V)             | `0.6`            |
| `imAiRangeMin`      | Minimum voltage of ADC input range (V)             | `-0.6`           |
| `imMaxInt`          | Maximum integer value for the ADC                  | `512`            |
| `imDatPrb_type`     | Probe type (0=NP1.0, 21=NP2.0 single-shank, etc.) | `0`              |
| `imDatPrb_sn`       | Probe serial number                                | `18005116102`    |
| `imroTbl`           | Channel map with per-channel gains                 | `(0,384)(0 0...)` |
| `typeThis`          | Stream type identifier                             | `imec`           |

### Channel subsets

When `snsSaveChanSubset` is not `all`, the user has selected a subset of
channels to save. The format uses 0-based channel indices:

- `0:383,768` — Save channels 0 through 383 and channel 768 (sync)
- `0,2,4,6` — Save only even channels 0, 2, 4, 6
- `0:95` — Save only the first 96 channels

The NDR reader handles this by parsing the subset specification and mapping
between file-order channel indices and original probe channel numbers.

## Voltage Conversion

Raw int16 values are converted to volts using the official SpikeGLX formula:

```
volts = int16_value * imAiRangeMax / imMaxInt / gain
```

where:
- `imAiRangeMax` = maximum ADC voltage (typically 0.6 V)
- `imMaxInt` = maximum ADC integer (512 for NP1.0, 8192 for NP2.0)
- `gain` = per-channel gain from `imroTbl` (typically 500 for NP1.0 AP, 250 for LF; 80 for NP2.0)

This yields ~2.34 uV/bit for NP1.0 AP and ~0.915 uV/bit for NP2.0 AP.

## NDR Design Decisions

### Scope of the reader

The `ndr.reader.neuropixelsGLX` reader handles **one probe's AP-band stream**
per instance. This means:

- Each `.ap.bin`/`.ap.meta` file pair is one epoch stream
- Multi-probe recordings use separate reader instances (one per `imec<N>`)
- LF-band and NI-DAQ streams are not handled by this reader (future work)

### Channel naming

Neural channels are named `ai1` through `aiN` where N is the number of neural
channels saved. The sync channel is exposed as `di1` (digital input). A time
channel `t1` is always present.

### Data type

The reader returns raw int16 data from `readchannels_epochsamples` to preserve
the native precision and enable efficient storage. Use
`ndr.format.neuropixelsGLX.samples2volts` for voltage conversion.

### Epoch structure

Each `.ap.bin` file represents a single epoch. The `filenamefromepochfiles`
method identifies the `.ap.meta` file from the epoch stream list, and the
corresponding `.ap.bin` file is derived from it.

## Format Functions

| Function        | Purpose                                               |
|-----------------|-------------------------------------------------------|
| `readmeta`      | Parse a `.meta` file into a key-value structure       |
| `header`        | Extract standardized recording parameters from `.meta`|
| `read`          | Read binary data with time/channel subsetting         |
| `samples2volts` | Convert raw int16 to voltage using gain parameters    |

## References

- [SpikeGLX Documentation](https://billkarsh.github.io/SpikeGLX/)
- [SpikeGLX Data Format](https://billkarsh.github.io/SpikeGLX/Support/SpikeGLX_Datafile_Tools.html)
- [Neuropixels](https://www.neuropixels.org/)
