# NDR-matlab

[![Version Number](https://img.shields.io/github/v/release/VH-Lab/NDR-matlab?label=version)](https://github.com/VH-Lab/NDR-matlab/releases/latest)
[![MATLAB Tests](https://raw.githubusercontent.com/VH-Lab/NDR-matlab/badges/main/tests.svg)](https://github.com/VH-Lab/NDR-matlab/actions/workflows/run_tests.yml)
[![codecov](https://codecov.io/gh/VH-Lab/NDR-matlab/graph/badge.svg?token=J347UBJ6FR)](https://codecov.io/gh/VH-Lab/NDR-matlab)
[![MATLAB Code Issues](https://raw.githubusercontent.com/VH-Lab/NDR-matlab/badges/main/code_issues.svg)](https://github.com/VH-Lab/NDR-matlab/security/code-scanning)
[![Maintenance](https://img.shields.io/badge/Maintained%3F-yes-green.svg)](https://gitHub.com/VH-Lab/NDR-matlab/graphs/commit-activity)

[Neuroscience Data Readers](https://ndr.vhlab.org) - A Matlab conglomerative package for reading neuroscience data files

## About

NDR-matlab is a package for reading neuroscience data files in a standard way. It includes some original code and some bundled code from
other open source projects. It will eventually provide the file reading functionality for [NDI](http://ndi.vhlab.org) (Neuroscience Data Interface) as NDI scales up but is available for use widely in many projects.

The package is focused around a central object called `ndr.reader`. This object can be used to read file metadata (such as the channels
that were turned on during the acquisition, the sampling rate, and other quantities) as well as file data.

The package is supported by a number of ndr.reader.* class objects that actually perform the reading of different file types in neuroscience.

It is intended that this package will be self-sufficient and not require other open source Matlab packages, although it does require
some Matlab toolboxes from The MathWorks.

This package is being developed with a companion Python package NDR-python. Sometimes, the Matlab package may call the Python package if Matlab code is not available for a certain file format.

## Supported formats

| Vendor/Format | Extension(s) | NDR Names | Support | Notes |
| ----------- | ----------- | ---- | ---- | ---- | 
| Intan RHD | `.rhd` | 'Intan', 'IntanRHD', 'RHD' | Native Matlab | |
| CED Spike2/SMR | `.smr` | 'SMR', 'Spike2', 'CEDSpike2' | Native Matlab via [sigTOOL](http://sigtool.sourceforge.net/sigtool.html) (included) | |
| SpikeGadgets | `.rec` | 'SpikeGadgets', 'SpikeGadgetsREC' | Native Matlab | |
| Blackrock Microsystems | '.NEV', 'NS#' | 'BlackrockNEV', 'BlackrockNS4', 'BlackrockNS5' | Native Matlab via NPMK (from Blackrock Microsystems) (included) | |

Dozens of other formats are supported via the integration with Neo-Python (see the list here - https://neo.readthedocs.io/en/stable/rawio.html#module-neo.rawio, note that NDR only suppports the Neo formats that implement `RawIO`).

## Blosc + Zstd chunk codec (self-installing)

Writing OME-Zarr chunks with `compressor: blosc/zstd` (and reading Blosc
containers back into MATLAB memory without shelling to the system `zstd`
binary) is available at `ndr.format.blosc.encode` / `ndr.format.blosc.decode`.

That path uses `numcodecs` (which bundles libblosc + libzstd) inside a
**private virtual environment** at `<NDR-matlab>/private_env/blosc/` that
NDR sets up on first use. Nothing here touches MATLAB's `pyenv` or the
customer's Python configuration -- the interpreter is only ever invoked
as a subprocess.

Requirements the first time you call `ndr.format.blosc.encode/decode`:

* A `python3` (3.9+) somewhere on PATH.
* Network access to PyPI on that first run.

After that first run, no network and no host `python3` are required.

If your machine has no `python3`, or is offline, pre-seed the venv:

```matlab
% Point at a specific Python installation:
ndr.util.blosc.setup('python', '/opt/homebrew/bin/python3');

% Or an offline install from pre-downloaded wheels:
ndr.util.blosc.setup('wheelDir', '/path/to/wheels');
```

`ndr.util.blosc.version()` returns the numcodecs/libblosc versions of
the installed venv -- run it once after installing as a smoke test.

## Licenses from other software

This package has files from a variety of distributions. It is our intention to only distribute code that is in the public domain or is licensed for re-distribution. If you find your code here that is not properly distributed please notify the maintainer.

## Funding

Supported by the [NIH BRAIN Initiative informatics group](https://braininitiative.nih.gov/brain-programs/informatics), grant MH114678.

