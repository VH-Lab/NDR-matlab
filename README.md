# NDR-matlab

[![Version Number](https://img.shields.io/github/v/release/VH-Lab/NDR-matlab?label=version)](https://github.com/VH-Lab/NDR-matlab/releases/latest)
[![MATLAB Tests](.github/badges/tests.svg)](https://github.com/VH-Lab/NDR-matlab/actions/workflows/run_tests.yml)
[![codecov](https://codecov.io/gh/VH-Lab/NDR-matlab/graph/badge.svg?token=J347UBJ6FR)](https://codecov.io/gh/VH-Lab/NDR-matlab)
[![MATLAB Code Issues](.github/badges/code_issues.svg)](https://github.com/VH-Lab/NDR-matlab/security/code-scanning)
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

## Licenses from other software

This package has files from a variety of distributions. It is our intention to only distribute code that is in the public domain or is licensed for re-distribution. If you find your code here that is not properly distributed please notify the maintainer.

## Funding

Supported by the [NIH BRAIN Initiative informatics group](https://braininitiative.nih.gov/brain-programs/informatics), grant MH114678.

