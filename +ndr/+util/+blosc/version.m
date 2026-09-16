function info = version()
% ndr.util.blosc.version - report versions inside the private Blosc venv.
%
%   INFO = ndr.util.blosc.version()
%
%   Returns a struct with fields:
%     numcodecs - char, numcodecs package version (e.g. '0.12.1')
%     blosc     - char, libblosc version numcodecs is linked against, or
%                 '' when the interpreter could not report it.
%
%   Triggers ndr.util.blosc.setup on first call, so this is a convenient
%   post-install sanity check: if it returns without error, the venv is
%   healthy.
%
%   See also: ndr.util.blosc.setup, ndr.util.blosc.pythonExe.

    raw = ndr.util.blosc.runTool('version', '', uint8([]));
    txt = char(raw(:)');
    payload = jsondecode(txt);
    info = struct( ...
        'numcodecs', asChar(getfieldsafe(payload, 'numcodecs')), ...
        'blosc',     asChar(getfieldsafe(payload, 'blosc')));
end

function v = getfieldsafe(s, name)
    if isstruct(s) && isfield(s, name)
        v = s.(name);
    else
        v = '';
    end
end

function s = asChar(v)
    if isempty(v)
        s = '';
    elseif ischar(v)
        s = v;
    elseif isstring(v)
        s = char(v);
    else
        s = char(string(v));
    end
end
