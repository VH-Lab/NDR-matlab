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
%   Uses the persistent per-process Blosc server if available; falls
%   back to a single one-shot subprocess call for the whole batch if
%   not. Same result as looping ndr.format.blosc.encode over RAWITEMS
%   at N times lower Python-startup overhead.

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

    slug = sprintf('cname=%s,clevel=%d,shuffle=%d,typesize=%d,blocksize=%d', ...
        options.cname, options.clevel, options.shuffle, ...
        options.typesize, options.blocksize);

    reqBody = ndr.util.blosc.packBatch(rawItems);

    respBody = tryServer('ENCB', slug, reqBody);
    if isempty(respBody)
        cliArgs = sprintf(['--cname %s --clevel %d --shuffle %d ' ...
            '--typesize %d --blocksize %d'], ...
            options.cname, options.clevel, options.shuffle, ...
            options.typesize, options.blocksize);
        respBody = ndr.util.blosc.runTool('encode_batch', cliArgs, reqBody);
    end

    encoded = ndr.util.blosc.unpackBatch(respBody);
end

function payload = tryServer(op, opts, body)
    payload = [];
    try
        payload = ndr.util.blosc.serverCall(op, opts, body);
    catch
    end
end
