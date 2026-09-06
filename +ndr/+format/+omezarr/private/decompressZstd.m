function bytesOut = decompressZstd(bytesIn, expectedSize)
% decompressZstd - Zstd decompression via the system `zstd` binary.
%
%   BYTESOUT = decompressZstd(BYTESIN)
%   BYTESOUT = decompressZstd(BYTESIN, EXPECTEDSIZE)
%
%   BYTESIN is a uint8 column vector holding one Zstd frame. Returns the
%   decompressed bytes as a uint8 column vector. EXPECTEDSIZE, when
%   given, is a sanity-check target -- the returned length must match it
%   or an error is raised, which turns a silently truncated zstd process
%   into a loud test failure.
%
%   MATLAB does not ship a Zstd decoder in base or in any of the
%   toolboxes NDR is willing to depend on (Image Processing Toolbox is
%   explicitly ruled out; R2025a's zarrread would bump the minimum
%   MATLAB version, which is also ruled out). This function therefore
%   shells out to the standard `zstd` command-line tool.
%
%   Rationale for shelling to a binary rather than writing a hand-rolled
%   Zstd decoder in MATLAB or building a MEX: issue #127 flagged the
%   hand-rolled route as exactly where subtle wrongness lives; a MEX
%   requires a build step per platform, which conflicts with NDR's
%   "install by adding to path" story. A tempfile round-trip is slower
%   per call but portable across every platform lab machines run on, and
%   the failure mode -- `zstd` not on PATH -- is loud rather than silent.
%
%   The temp files are placed in tempdir() with unique names, cleaned up
%   with onCleanup so an error mid-decompression does not leave them
%   behind, and read back with a native binary read.

    if nargin < 2
        expectedSize = [];
    end
    if ~isa(bytesIn, 'uint8')
        bytesIn = typecast(bytesIn(:), 'uint8');
    end
    bytesIn = bytesIn(:);

    zstdBin = locateZstdBinary();

    inPath  = [tempname() '.zst'];
    outPath = [tempname() '.bin'];
    cleaner = onCleanup(@() cleanupTempFiles({inPath, outPath}));

    fid = fopen(inPath, 'wb');
    if fid < 0
        error('ndr:format:omezarr:readArray:ZstdTempWriteFailed', ...
            'Could not create temp file %s for zstd input.', inPath);
    end
    try
        fwrite(fid, bytesIn, 'uint8');
        fclose(fid);
    catch ME
        try
            fclose(fid);
        catch
        end
        rethrow(ME);
    end

    cmd = sprintf('%s -dqf -o %s %s', ...
        shellQuote(zstdBin), shellQuote(outPath), shellQuote(inPath));
    [status, out] = system(cmd);
    if status ~= 0
        error('ndr:format:omezarr:readArray:ZstdFailed', ...
            'zstd decompression failed (exit %d): %s', status, strtrim(out));
    end

    fid2 = fopen(outPath, 'rb');
    if fid2 < 0
        error('ndr:format:omezarr:readArray:ZstdOutputMissing', ...
            'zstd reported success but %s does not exist.', outPath);
    end
    try
        bytesOut = fread(fid2, inf, '*uint8');
        fclose(fid2);
    catch ME
        try
            fclose(fid2);
        catch
        end
        rethrow(ME);
    end

    if ~isempty(expectedSize) && numel(bytesOut) ~= expectedSize
        error('ndr:format:omezarr:readArray:ZstdSizeMismatch', ...
            'zstd returned %d bytes; expected %d.', ...
            numel(bytesOut), expectedSize);
    end
end

function bin = locateZstdBinary()
% Locate the `zstd` executable, or error with a message that names how
% to install it. Cached per-process because `which` is not free.
    persistent cached
    if ~isempty(cached)
        bin = cached;
        return;
    end
    if ispc
        [s, out] = system('where zstd');
    else
        [s, out] = system('command -v zstd');
    end
    if s == 0
        lines = strsplit(strtrim(out), newline);
        candidate = strtrim(lines{1});
        if ~isempty(candidate) && exist(candidate, 'file') == 2
            cached = candidate;
            bin = cached;
            return;
        end
    end
    error('ndr:format:omezarr:readArray:ZstdNotFound', ...
        ['The `zstd` executable is required to read Blosc+Zstd ' ...
         'compressed OME-Zarr chunks and was not found on PATH. ' ...
         'Install it: `apt install zstd` (Debian/Ubuntu), ' ...
         '`brew install zstd` (macOS), or download from ' ...
         'https://github.com/facebook/zstd/releases (Windows).']);
end

function s = shellQuote(p)
    if ispc
        s = ['"' p '"'];
    else
        s = ['''' strrep(p, '''', '''\''''') ''''];
    end
end

function cleanupTempFiles(paths)
    for i = 1:numel(paths)
        p = paths{i};
        if ~isempty(p) && exist(p, 'file') == 2
            try
                delete(p);
            catch
                % Best-effort; a leftover file is harmless.
            end
        end
    end
end
