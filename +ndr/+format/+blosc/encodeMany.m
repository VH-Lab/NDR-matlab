function encoded = encodeMany(rawItems, options)
% ndr.format.blosc.encodeMany - encode many raw byte arrays in one round-trip
%
%   OUT = ndr.format.blosc.ENCODEMANY(RAWITEMS, ...)
%
%   RAWITEMS is a cell array of uint8 column vectors of raw bytes.
%   Every item in the batch is encoded with the SAME codec options.
%   Returns a cell array of the same size where OUT{i} is the Blosc
%   container for RAWITEMS{i}.
%
%   Optional name-value arguments (defaults mirror ndr.format.blosc.encode):
%     'cname'     - char, one of {'zstd','lz4','lz4hc','blosclz'};
%                   default 'zstd'.
%     'clevel'    - integer 1..9; default 5.
%     'shuffle'   - integer 0/1/2; default 1 (byte shuffle).
%     'typesize'  - integer >= 1, item size in bytes; default 1.
%     'blocksize' - integer >= 0; default 0 (auto).
%
%   Fast path: the blosc-matlab MEX (a direct C call, ~microseconds per
%   chunk, no subprocess). If the MEX is not available on this platform
%   or the download fails, falls back to a one-shot invocation of
%   blosc_tool.py that handles the whole batch in a single subprocess.
%
%   This function itself is SERIAL over the batch. Callers who want
%   parallel throughput should call it from within a parfor, one
%   sub-batch per worker; the MEX is thread-safe (blosc_compress_ctx
%   with nthreads=1). See the discussion in +ndr/+util/+blosc/ensureMex.

    arguments
        rawItems (1,:) cell
        options.cname (1,:) char {mustBeMember(options.cname, {'zstd','lz4','lz4hc','blosclz'})} = 'zstd'
        options.clevel (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(options.clevel, 1), mustBeLessThanOrEqual(options.clevel, 9)} = 5
        options.shuffle (1,1) double {mustBeMember(options.shuffle, [0 1 2])} = 1
        options.typesize (1,1) double {mustBeInteger, mustBePositive} = 1
        options.blocksize (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(options.blocksize, 0)} = 0
    end

    n = numel(rawItems);
    if n == 0
        encoded = {};
        return;
    end

    mexInfo = ndr.util.blosc.ensureMex();
    if mexInfo.available
        encoded = cell(size(rawItems));
        for i = 1:n
            encoded{i} = blosc.encode(rawItems{i}, ...
                'cname',     options.cname, ...
                'clevel',    options.clevel, ...
                'shuffle',   options.shuffle, ...
                'typesize',  options.typesize, ...
                'blocksize', options.blocksize);
        end
        return;
    end

    reqBody = ndr.util.blosc.packBatch(rawItems);
    cliArgs = sprintf(['--cname %s --clevel %d --shuffle %d ' ...
        '--typesize %d --blocksize %d'], ...
        options.cname, options.clevel, options.shuffle, ...
        options.typesize, options.blocksize);
    respBody = ndr.util.blosc.runTool('encode_batch', cliArgs, reqBody);
    encoded = ndr.util.blosc.unpackBatch(respBody);
end
