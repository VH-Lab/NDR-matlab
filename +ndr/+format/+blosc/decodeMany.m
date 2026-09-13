function decompressed = decodeMany(containers)
% ndr.format.blosc.decodeMany - decode many Blosc containers in one round-trip
%
%   OUT = ndr.format.blosc.DECODEMANY(CONTAINERS)
%
%   CONTAINERS is a cell array of uint8 column vectors, each a
%   Blosc v1 container. Returns a cell array of the same size where
%   OUT{i} is the raw uncompressed bytes of CONTAINERS{i}.
%
%   Uses the persistent per-process Blosc server if one is running
%   (see ndr.util.blosc.serverConnect); the whole batch is one
%   request over the pipe and Python is not respawned. If the server
%   cannot be reached, falls back to a one-shot subprocess call
%   (still one for the whole batch, not one per container). Either
%   way, decoding N containers costs at most one subprocess spawn.
%
%   Same result as looping ndr.format.blosc.decode over CONTAINERS,
%   at N times lower Python-startup overhead. Callers doing a large
%   readArray should always prefer this to the singular form.

    if ~iscell(containers)
        error('ndr:format:blosc:decodeMany:BadInput', ...
            'CONTAINERS must be a cell array.');
    end
    n = numel(containers);
    if n == 0
        decompressed = {};
        return;
    end

    reqBody = ndr.util.blosc.packBatch(containers);

    respBody = tryServer('DECB', '', reqBody);
    if isempty(respBody)
        respBody = ndr.util.blosc.runTool('decode_batch', '', reqBody);
    end

    decompressed = ndr.util.blosc.unpackBatch(respBody);
end

function payload = tryServer(op, opts, body)
% tryServer - one attempt at the persistent server, returning [] on failure
%
%   Any exception from the server (spawn refused, protocol error,
%   process died mid-request) falls through to the tempfile-based
%   runTool path. That keeps decodeMany working on machines where
%   the Java bridge is unavailable or the server refused to start.
    payload = [];
    try
        payload = ndr.util.blosc.serverCall(op, opts, body);
    catch
    end
end
