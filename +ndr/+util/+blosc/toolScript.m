function p = toolScript()
% ndr.util.blosc.toolScript - absolute path to the blosc_tool.py worker.
%
%   P = ndr.util.blosc.toolScript()
%
%   Returns the on-disk path to <NDR-matlab>/tools/blosc_tool.py, which
%   ndr.format.blosc.encode/decode invoke as a subprocess. Kept as a
%   separate function so tests can override it and callers do not have to
%   duplicate the "walk up the +ndr/+util/+blosc tree" logic.
%
%   See also: ndr.util.blosc.runTool.

    thisFile = mfilename('fullpath');
    thisDir  = fileparts(thisFile);                    % .../+ndr/+util/+blosc
    toolboxRoot = fileparts(fileparts(fileparts(thisDir)));
    p = fullfile(toolboxRoot, 'tools', 'blosc_tool.py');
end
