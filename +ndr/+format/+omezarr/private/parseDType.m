function info = parseDType(dtypeStr)
% parseDType - decode a Zarr v2 dtype string like '<u2'.
%
%   INFO = parseDType(DTYPESTR)
%
%   INFO is a struct with fields:
%     mlType     - MATLAB numeric class name ('uint8', 'uint16', ...)
%     itemBytes  - number of bytes per element (1, 2, 4, 8)
%     byteorder  - 'little', 'big', or 'native' (from the leading char)
%     needSwap   - logical, true if bytes must be swapped to match the
%                  host's native order (assumed little on all platforms
%                  NDR runs on)
%
%   Only the fixed-length numeric dtypes the lab uses today are
%   supported (u/i/f, sizes 1/2/4/8). Anything else errors clearly.

    if isstring(dtypeStr) && isscalar(dtypeStr)
        dtypeStr = char(dtypeStr);
    end
    if ~(ischar(dtypeStr) && numel(dtypeStr) >= 2)
        error('ndr:format:omezarr:readArray:BadDType', ...
            'dtype string is too short: %s', mat2str(dtypeStr));
    end

    switch dtypeStr(1)
        case '<'
            byteorder = 'little';
        case '>'
            byteorder = 'big';
        case {'|', '='}
            byteorder = 'native';
        otherwise
            error('ndr:format:omezarr:readArray:BadDType', ...
                'Unrecognized dtype byteorder in "%s".', dtypeStr);
    end

    kind = dtypeStr(2);
    sizeStr = dtypeStr(3:end);
    itemBytes = str2double(sizeStr);
    if ~(isscalar(itemBytes) && isfinite(itemBytes) && itemBytes > 0 ...
            && itemBytes == floor(itemBytes))
        error('ndr:format:omezarr:readArray:BadDType', ...
            'dtype "%s" has an unreadable element size.', dtypeStr);
    end

    switch kind
        case 'u'
            mlType = sprintf('uint%d', 8 * itemBytes);
        case 'i'
            mlType = sprintf('int%d', 8 * itemBytes);
        case 'f'
            mlType = sprintf('single');
            if itemBytes == 8
                mlType = 'double';
            elseif itemBytes ~= 4
                error('ndr:format:omezarr:readArray:UnsupportedDType', ...
                    'Only float32 and float64 are supported; got "%s".', dtypeStr);
            end
        otherwise
            error('ndr:format:omezarr:readArray:UnsupportedDType', ...
                ['dtype kind "%c" is not supported. Supported kinds ' ...
                 'are u (unsigned int), i (signed int), and f (float).'], kind);
    end

    switch mlType
        case {'uint8','int8','uint16','int16','uint32','int32', ...
              'uint64','int64','single','double'}
            % OK.
        otherwise
            error('ndr:format:omezarr:readArray:UnsupportedDType', ...
                'dtype "%s" maps to unsupported MATLAB class "%s".', ...
                dtypeStr, mlType);
    end

    info = struct( ...
        'mlType',    mlType, ...
        'itemBytes', itemBytes, ...
        'byteorder', byteorder, ...
        'needSwap',  strcmp(byteorder, 'big'));
end
