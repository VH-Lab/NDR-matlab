function meta = readZArrayMeta(arrayDir)
% readZArrayMeta - parse a Zarr v2 array's .zarray, with the fields the
% pixel reader needs.
%
%   META = readZArrayMeta(ARRAYDIR)
%
%   Fields returned:
%     shape         - numeric row vector (as-stored order, typically CZYX)
%     chunks        - numeric row vector, same length as shape
%     dtype         - char, raw dtype string ('<u2', '<f4', ...)
%     dtypeInfo     - struct from parseDType (mlType, itemBytes, needSwap)
%     fillValue     - scalar of dtypeInfo.mlType (cast from .zarray's
%                     fill_value, or the type's zero if fill_value is null)
%     order         - 'C' or 'F' (only 'C' is supported downstream)
%     compressorName- lowercase char: 'zstd' etc, or '' if uncompressed
%     compressor    - the raw struct from .zarray (for future codecs)
%     dimSep        - '.' (v2 default) or '/'
%
%   This is the metadata the pixel reader (readArray) needs on top of
%   what listPyramids already surfaces. It is deliberately narrower than
%   listPyramids: it does not touch NGFF multiscales, coordinate
%   transforms, or the parent .zattrs.

    zarrayPath = fullfile(arrayDir, '.zarray');
    if ~isfile(zarrayPath)
        error('ndr:format:omezarr:readArray:MissingZArray', ...
            'No .zarray at %s.', zarrayPath);
    end
    raw = fileread(zarrayPath);
    try
        j = jsondecode(raw);
    catch ME
        error('ndr:format:omezarr:readArray:BadZArray', ...
            'Failed to parse %s: %s', zarrayPath, ME.message);
    end

    if ~isfield(j, 'zarr_format') || j.zarr_format ~= 2
        error('ndr:format:omezarr:readArray:UnsupportedZarrVersion', ...
            ['Only Zarr v2 stores are supported here (this array ' ...
             'reports zarr_format=%s in %s).'], ...
            zarrFmtStr(j), zarrayPath);
    end

    requireField(j, 'shape',  zarrayPath);
    requireField(j, 'chunks', zarrayPath);
    requireField(j, 'dtype',  zarrayPath);

    meta.shape  = reshape(double(j.shape),  1, []);
    meta.chunks = reshape(double(j.chunks), 1, []);
    meta.dtype  = char(j.dtype);

    if numel(meta.shape) ~= numel(meta.chunks)
        error('ndr:format:omezarr:readArray:ShapeChunksMismatch', ...
            ['.zarray shape and chunks have different lengths ' ...
             '(%d vs %d) in %s.'], ...
            numel(meta.shape), numel(meta.chunks), zarrayPath);
    end

    meta.dtypeInfo = parseDType(meta.dtype);

    if isfield(j, 'order') && ~isempty(j.order)
        meta.order = upper(char(j.order));
    else
        meta.order = 'C';
    end
    if ~strcmp(meta.order, 'C')
        error('ndr:format:omezarr:readArray:UnsupportedOrder', ...
            ['Only C-order arrays are supported; .zarray in %s ' ...
             'reports order "%s".'], zarrayPath, meta.order);
    end

    meta.compressor = struct();
    meta.compressorName = '';
    if isfield(j, 'compressor') && ~isempty(j.compressor) ...
            && (isstruct(j.compressor) || isa(j.compressor, 'containers.Map'))
        meta.compressor = j.compressor;
        cid = getStringField(meta.compressor, 'id');
        cname = getStringField(meta.compressor, 'cname');
        if strcmpi(cid, 'blosc')
            meta.compressorName = lower(cname);
        else
            error('ndr:format:omezarr:readArray:UnsupportedCompressor', ...
                ['Only the Blosc container is supported; .zarray in ' ...
                 '%s reports compressor id "%s".'], zarrayPath, cid);
        end
    end

    if isfield(j, 'filters') && ~isempty(j.filters)
        error('ndr:format:omezarr:readArray:UnsupportedFilters', ...
            ['This reader does not support Zarr filters; .zarray in ' ...
             '%s declares one.'], zarrayPath);
    end

    if isfield(j, 'dimension_separator') && ~isempty(j.dimension_separator)
        sep = char(j.dimension_separator);
        if ~any(strcmp(sep, {'.', '/'}))
            error('ndr:format:omezarr:readArray:BadDimensionSeparator', ...
                'dimension_separator must be "." or "/"; got "%s".', sep);
        end
        meta.dimSep = sep;
    else
        meta.dimSep = '.';
    end

    if isfield(j, 'fill_value') && ~isempty(j.fill_value)
        fv = j.fill_value;
        if ischar(fv) || (isstring(fv) && isscalar(fv))
            fvStr = lower(strtrim(char(fv)));
            switch fvStr
                case {'nan'}
                    fv = NaN;
                case {'infinity', 'inf', '+infinity', '+inf'}
                    fv = Inf;
                case {'-infinity', '-inf'}
                    fv = -Inf;
                otherwise
                    fvNum = str2double(fvStr);
                    if isnan(fvNum) && ~any(strcmp(fvStr, {'nan'}))
                        error('ndr:format:omezarr:readArray:BadFillValue', ...
                            'Cannot interpret fill_value "%s".', fvStr);
                    end
                    fv = fvNum;
            end
        end
        meta.fillValue = safeCast(fv, meta.dtypeInfo.mlType);
    else
        meta.fillValue = zeros(1, 1, meta.dtypeInfo.mlType);
    end
end

function requireField(s, name, where)
    if ~isfield(s, name)
        error('ndr:format:omezarr:readArray:MissingZArrayField', ...
            '.zarray at %s is missing required field "%s".', where, name);
    end
end

function s = zarrFmtStr(j)
    if isfield(j, 'zarr_format')
        s = mat2str(j.zarr_format);
    else
        s = '(missing)';
    end
end

function v = getStringField(s, name)
    v = '';
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        v = char(s.(name));
    end
end

function out = safeCast(val, mlType)
    switch mlType
        case {'single','double'}
            out = cast(val, mlType);
        otherwise
            out = cast(val, mlType);
    end
end
