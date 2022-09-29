To use neo, it is necessary to install exactly python3.9.

In macOS, on a terminal run:

```
brew install pyenv
pyenv install 3.9.0
python3.9 -m pip install neo
python3.9 -m pip install sonpy
```

In Matlab, before using neo, establish Python 3.9 as a valid Matlab python environment by calling

```
pyenv('3.9.0',*path_to_your_executable*)
```

In macOS for me this is

```
pyenv('Version','/usr/local/bin/python3.9')
```

All set.




Development notes:


We need Python 3.9.0 (not bigger!) for sonpy.

~/Desktop❯ python3 --version
Python 3.9.0
~/Desktop❯ pip3 install sonpy
Collecting sonpy


ERROR: Ignored the following versions that require a different python version:
1.1   Requires-Python >=3.9, <3.10;
1.7.1 Requires-Python >=3.7, <3.8;
1.7.2 Requires-Python >=3.7, <3.8; 
1.7.3 Requires-Python >=3.7, <3.8; 
1.7.5 Requires-Python >=3.7, <3.8; 
1.8.1 Requires-Python >=3.8, <3.9; 
1.8.2 Requires-Python >=3.8, <3.9; 
1.8.3 Requires-Python >=3.8, <3.9; 
1.8.5 Requires-Python >=3.8, <3.9; 
1.9.1 Requires-Python >=3.9, <3.10; 
1.9.2 Requires-Python >=3.9, <3.10; 
1.9.3 Requires-Python >=3.9, <3.10; 
1.9.5 Requires-Python >=3.9, <3.10
