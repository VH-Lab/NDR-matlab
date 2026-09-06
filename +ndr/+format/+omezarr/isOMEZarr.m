function tf = isOMEZarr(zarrPath)
% ndr.format.omezarr.isOMEZarr - is this directory a readable OME-Zarr store?
%
%   TF = ndr.format.omezarr.ISOMEZARR(ZARRPATH)
%
%   Cheap non-throwing probe: returns TRUE if ZARRPATH is a directory
%   holding a .zattrs whose parsed contents carry a non-empty
%   `multiscales` field, FALSE otherwise. Any read or JSON-decode failure
%   returns FALSE rather than raising, so callers can use this to decide
%   whether to attempt the OME-Zarr code path at all.
%
%   This does not validate the whole NGFF spec -- it only confirms enough
%   for the discovery functions to make sense.

    tf = false;

    if ~(ischar(zarrPath) || (isstring(zarrPath) && isscalar(zarrPath)))
        return;
    end
    zarrPath = char(zarrPath);

    if ~isfolder(zarrPath)
        return;
    end

    zattrsPath = fullfile(zarrPath, '.zattrs');
    if ~isfile(zattrsPath)
        return;
    end

    try
        raw = fileread(zattrsPath);
        attrs = jsondecode(raw);
    catch
        return;
    end

    if ~isstruct(attrs) || ~isfield(attrs, 'multiscales')
        return;
    end

    ms = attrs.multiscales;
    if isempty(ms)
        return;
    end

    tf = true;
end
