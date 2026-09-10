function outBytes = runTool(subcommand, args, inBytes)
% ndr.util.blosc.runTool - invoke blosc_tool.py with stdin/stdout binary I/O.
%
%   OUTBYTES = ndr.util.blosc.runTool(SUBCOMMAND, ARGS, INBYTES)
%
%   Internal helper for ndr.format.blosc.encode/decode. Writes INBYTES to
%   a tempfile, invokes the private venv's python on tools/blosc_tool.py
%   with the given SUBCOMMAND and ARGS string, and returns the tool's
%   stdout as a uint8 column vector.
%
%   Piping raw binary bytes on stdin/stdout of MATLAB `system` is not
%   portable across shells; a tempfile round-trip is. onCleanup removes
%   the tempfiles even on error.
%
%   Not part of the stable API. Callers outside +ndr are expected to
%   use ndr.format.blosc.encode / decode.

    if nargin < 3
        inBytes = uint8([]);
    end
    if ~isa(inBytes, 'uint8')
        inBytes = typecast(inBytes(:), 'uint8');
    end
    inBytes = inBytes(:);

    pyExe = ndr.util.blosc.pythonExe();
    tool  = ndr.util.blosc.toolScript();
    if ~isfile(tool)
        error('ndr:util:blosc:runTool:ToolMissing', ...
            'blosc_tool.py not found at %s.', tool);
    end

    inPath  = [tempname() '.in.bin'];
    outPath = [tempname() '.out.bin'];
    errPath = [tempname() '.err.log'];
    cleaner = onCleanup(@() cleanupFiles({inPath, outPath, errPath}));

    writeBinary(inPath, inBytes);

    cmd = sprintf('%s %s %s %s < %s > %s 2> %s', ...
        shellQuote(pyExe), shellQuote(tool), subcommand, args, ...
        shellQuote(inPath), shellQuote(outPath), shellQuote(errPath));
    [status, ~] = system(cmd);
    if status ~= 0
        errText = readTextFile(errPath);
        error('ndr:util:blosc:runTool:ToolFailed', ...
            'blosc_tool %s failed (exit %d): %s', subcommand, status, errText);
    end

    outBytes = readBinary(outPath);
end

function writeBinary(path, bytes)
    fid = fopen(path, 'wb');
    if fid < 0
        error('ndr:util:blosc:runTool:TempWriteFailed', ...
            'Could not create tempfile %s.', path);
    end
    closer = onCleanup(@() safeClose(fid));
    fwrite(fid, bytes, 'uint8');
end

function bytes = readBinary(path)
    if exist(path, 'file') ~= 2
        error('ndr:util:blosc:runTool:OutputMissing', ...
            'blosc_tool reported success but %s does not exist.', path);
    end
    fid = fopen(path, 'rb');
    if fid < 0
        error('ndr:util:blosc:runTool:OutputUnreadable', ...
            'Could not open %s for reading.', path);
    end
    closer = onCleanup(@() safeClose(fid));
    bytes = fread(fid, inf, '*uint8');
end

function safeClose(fid)
    if fid >= 0
        fclose(fid);
    end
end

function s = shellQuote(p)
    if ispc
        s = ['"' p '"'];
    else
        s = ['''' strrep(p, '''', '''\''''') ''''];
    end
end

function cleanupFiles(paths)
    for i = 1:numel(paths)
        p = paths{i};
        if ~isempty(p) && exist(p, 'file') == 2
            try
                delete(p);
            catch
                % best-effort
            end
        end
    end
end

function txt = readTextFile(p)
    txt = '';
    if exist(p, 'file') ~= 2
        return;
    end
    fid = fopen(p, 'r');
    if fid < 0
        return;
    end
    try
        txt = strtrim(fread(fid, inf, '*char')');
        fclose(fid);
    catch
        try, fclose(fid); catch, end %#ok<CTCH>
    end
end
