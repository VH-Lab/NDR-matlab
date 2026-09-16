function decompressed = decodeMany(containers)
% ndr.format.blosc.decodeMany - decode many Blosc containers in one round-trip
%
%   OUT = ndr.format.blosc.DECODEMANY(CONTAINERS)
%
%   CONTAINERS is a cell array of uint8 column vectors, each a
%   Blosc v1 container. Returns a cell array of the same size where
%   OUT{i} is the raw uncompressed bytes of CONTAINERS{i}.
%
%   Fast path: the blosc-matlab MEX (a direct C call, ~microseconds
%   per chunk, no subprocess). If the MEX is not available on this
%   platform or the download fails, falls back to a one-shot
%   invocation of blosc_tool.py that handles the whole batch in a
%   single subprocess. Same result as looping ndr.format.blosc.decode
%   over CONTAINERS, at N times lower Python-startup overhead.
%
%   This function itself is SERIAL over the batch. Callers who want
%   parallel throughput should call it from within a parfor, one
%   sub-batch per worker; the MEX is thread-safe
%   (blosc_decompress_ctx with nthreads=1). No parpool is required
%   for correctness -- the MEX is fast enough on a single MATLAB
%   thread for typical read patterns.

    if ~iscell(containers)
        error('ndr:format:blosc:decodeMany:BadInput', ...
            'CONTAINERS must be a cell array.');
    end
    n = numel(containers);
    if n == 0
        decompressed = {};
        return;
    end

    mexInfo = ndr.util.blosc.ensureMex();
    if mexInfo.available
        decompressed = cell(size(containers));
        for i = 1:n
            decompressed{i} = blosc.decode(containers{i});
        end
        return;
    end

    reqBody = ndr.util.blosc.packBatch(containers);
    respBody = ndr.util.blosc.runTool('decode_batch', '', reqBody);
    decompressed = ndr.util.blosc.unpackBatch(respBody);
end
