function pyExe = pythonExe()
% ndr.util.blosc.pythonExe - path to the Python interpreter that runs blosc_tool.py.
%
%   PYEXE = ndr.util.blosc.pythonExe()
%
%   Returns the absolute path to the Python interpreter inside NDR's
%   private Blosc venv. On the first call in a fresh install this
%   triggers ndr.util.blosc.setup, which creates the venv under
%   <NDR-matlab>/private_env/blosc and pip-installs numcodecs. Later
%   calls just return the cached path.
%
%   The venv is isolated from MATLAB's own `pyenv` and from the
%   customer's Python configuration; NDR never calls `pyenv` or `py.`.
%   The interpreter is only ever invoked via system() with stdin/stdout
%   tempfiles carrying binary data.
%
%   See also: ndr.util.blosc.setup, ndr.util.blosc.venvDir,
%             ndr.util.blosc.version.

    persistent cachedExe
    if ~isempty(cachedExe) && isfile(cachedExe)
        pyExe = cachedExe;
        return;
    end
    pyExe = ndr.util.blosc.setup();
    cachedExe = pyExe;
end
