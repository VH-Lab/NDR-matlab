function d = venvDir()
% ndr.util.blosc.venvDir - absolute path where the private Blosc venv lives.
%
%   D = ndr.util.blosc.venvDir()
%
%   Returns the directory that ndr.util.blosc.setup creates the private
%   virtualenv in. The venv holds `numcodecs` (which brings its own
%   bundled libblosc and libzstd) and is invoked as a subprocess by
%   ndr.format.blosc.encode/decode.
%
%   The path is <NDR-matlab-root>/private_env/blosc/. It sits inside
%   the toolbox checkout so an `rm -rf` of the checkout removes it too,
%   and so multiple NDR-matlab checkouts stay isolated from each other.
%
%   `private_env/` is deliberately named -- the `private/` bare word is
%   a MATLAB keyword directory that changes function-scope semantics.
%
%   See also: ndr.util.blosc.setup, ndr.util.blosc.pythonExe.

    thisFile = mfilename('fullpath');
    thisDir  = fileparts(thisFile);                    % .../+ndr/+util/+blosc
    toolboxRoot = fileparts(fileparts(fileparts(thisDir)));
    d = fullfile(toolboxRoot, 'private_env', 'blosc');
end
