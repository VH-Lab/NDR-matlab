function attrs = readAttrs(zarrPath)
% ndr.format.omezarr.readAttrs - parse the .zattrs of an OME-Zarr store
%
%   ATTRS = ndr.format.omezarr.READATTRS(ZARRPATH)
%
%   Reads <ZARRPATH>/.zattrs and returns the parsed contents as a struct.
%   Errors if the directory does not exist, .zattrs is absent, or the
%   JSON cannot be decoded.
%
%   This is the low-level metadata primitive; listPyramids builds on it.
%   Callers who need the full NGFF metadata (omero, name, etc.) can read
%   it here without walking a normalized form.

    if isstring(zarrPath) && isscalar(zarrPath)
        zarrPath = char(zarrPath);
    end
    if ~(ischar(zarrPath) && ~isempty(zarrPath))
        error('ndr:format:omezarr:readAttrs:BadInput', ...
            'zarrPath must be a non-empty char or scalar string.');
    end

    if ~isfolder(zarrPath)
        error('ndr:format:omezarr:readAttrs:NotADirectory', ...
            'Not a directory: %s', zarrPath);
    end

    zattrsPath = fullfile(zarrPath, '.zattrs');
    if ~isfile(zattrsPath)
        error('ndr:format:omezarr:readAttrs:MissingZattrs', ...
            'No .zattrs found in %s', zarrPath);
    end

    raw = fileread(zattrsPath);
    try
        attrs = jsondecode(raw);
    catch ME
        error('ndr:format:omezarr:readAttrs:InvalidJSON', ...
            'Failed to parse %s as JSON: %s', zattrsPath, ME.message);
    end
end
