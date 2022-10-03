To use neo, it is necessary to install exactly python3.9 (because of Neo's `sonpy` dependency).

# Setting up Neo

In macOS, on a terminal run:

```
brew install pyenv
pyenv install 3.9.0
python3.9 -m pip install neo
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

One gotcha is Neo determines what file reader to use via file extensions.  
With some formats, this is not straightforward. For example, for the Blackrock reader, we have to:
- leave `example_1.nev` with the `.nev` extension
- however call `intan_reader.read({ 'example_1.ns2' }, ...)`,
so that Neo knows to instantiate the Blackrock reader!  
If necessary, this could be fixed by telling Neo exactly what reader to instantiate.

# Further development

Here is the initial Neo PR: https://github.com/VH-Lab/NDR-matlab/pull/56.
It outlines remaining the TODOs, and gives some tips on development.
