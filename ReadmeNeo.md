To use neo, it is necessary to install exactly python3.9 (because of Neo's `sonpy` dependency).

# Setting up Neo

In macOS, on a terminal run:

```
brew install pyenv
pyenv install 3.9.0
python3.9 -m pip install numpy==1.22.4
python3.9 -m pip install neo==0.10.2
python3.9 -m pip install sonpy
```

In Matlab, before using neo, establish Python 3.9 as a valid Matlab python environment by calling

```
pyenv('3.9.0', *path_to_your_executable*)
```

In macOS for me this is

```
pyenv('Version','/usr/local/bin/python3.9')
```

All set.

# Using Neo

Take a look at `+neo/automatedTest.m` to see how to use Neo and what output to expect.  

Unlike with other readers, Neo expects device-native channel names in its every method (the `channel` parameter always expects a cell array of channel names, e.g. `{ 'A-000', 'A-001' }`).

# Gotchas

## Channel types

Neo doesn't have a way to determine a specific NDR type of a channel. Neo only divides channels into 3 NDR types: `analog_input` (Neo's `signal_channels`), `event` (Neo's `spike_channels`), and `marker` (Neo's `event_channels`). So, the types you will see returned from the NDR reader might differ from those returned from the Neo reader (for the same file).  

## Available channels

Both the readers implemented in NDR and the readers implemented in Neo don't necessarily return all available channels.
So, the number of channels might differ (as well as channel types). Here are two examples:

```
// ced_smr .smr
NDR: 14 channels (2 analog_in, |||8 event, 1 text, 3 mark)
NEO: 3 channels (2 signal channels, 1 spike channel)
```

```
// spikegadgets_rec .rec
NDR: 204 channels (120 analog_in, 12 auxiliary, |||40 digital_in, 32 digital_out)
NEO: 132 channels (120 trodes, 8 analog_in, 4 analog_out)
// Confirmed: NEO's "analog_in", "analog_out" channels = NDR's "auxiliary" channel
```

## File extensions

One gotcha is Neo determines what file reader to use via file extensions.  
With some formats, this is not straightforward. For example, for the Blackrock reader, we have to:
- leave `example_1.nev` with the `.nev` extension
- however call `intan_reader.read({ 'example_1.ns2' }, ...)`,
so that Neo knows to instantiate the Blackrock reader!  
If necessary, this could be fixed by telling Neo exactly what reader to instantiate.

# Further development

Here is the initial Neo PR: https://github.com/VH-Lab/NDR-matlab/pull/56.
It outlines remaining the TODOs, and gives some tips on development.
