function out = reduce(arr, factor, reduction)
% ndr.format.omezarr.reduce - block-reduce an array for pyramid building
%
%   OUT = NDR.FORMAT.OMEZARR.REDUCE(ARR, FACTOR, REDUCTION)
%
%   Downsample ARR by FACTOR (scalar or per-axis vector) using
%   REDUCTION ('mean' or 'max'). Used when materializing a new
%   pyramid level from a coarser reduction of a finer one.
%
%   The trailing partial block along each axis is included: an axis
%   of length 5 with factor 2 produces 3 output samples (blocks of
%   size 2, 2, 1). That matches how NGFF-writing tools we consume
%   from (bioformats2raw, ferret-lightsheet make_zarr_levels.py) size
%   the coarser levels.
%
%   Only accepts numeric arrays. dtype is preserved for `max`; `mean`
%   returns double.

    arguments
        arr {mustBeNumeric}
        factor (1,:) double {mustBePositive, mustBeInteger}
        reduction (1,:) char {mustBeMember(reduction, {'mean','max'})}
    end

    sz = size(arr);
    nd = numel(sz);

    if isscalar(factor)
        f = repmat(factor, 1, nd);
    else
        if numel(factor) ~= nd
            error('ndr:format:omezarr:reduce:BadFactor', ...
                'factor must be scalar or numel(size(arr)); got %d for a %d-D array.', ...
                numel(factor), nd);
        end
        f = factor(:).';
    end

    outSize = ceil(sz ./ f);

    switch reduction
        case 'mean'
            out = zeros(outSize, 'like', double(arr));
        case 'max'
            out = zeros(outSize, 'like', arr);
    end

    % Simple, correct, not optimised. Bad news if you call this on the
    % full level-0 volume; good enough for the small ranks used by the
    % existing NGFF writers (factor 2 across z/y/x).
    idx = cell(1, nd);
    for lin = 1:prod(outSize)
        [subs{1:nd}] = ind2sub(outSize, lin); %#ok<AGROW>
        for d = 1:nd
            lo = (subs{d} - 1) * f(d) + 1;
            hi = min(sz(d), subs{d} * f(d));
            idx{d} = lo:hi;
        end
        block = arr(idx{:});
        switch reduction
            case 'mean'
                out(subs{:}) = mean(double(block(:)));
            case 'max'
                out(subs{:}) = max(block(:));
        end
    end
end
