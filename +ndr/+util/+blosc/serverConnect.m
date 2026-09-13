function h = serverConnect()
% ndr.util.blosc.serverConnect - get or start the persistent blosc server
%
%   H = ndr.util.blosc.serverConnect()
%
%   Returns a struct with fields:
%     process - the java.lang.Process handle
%     in      - java.io.DataOutputStream for writing to the tool's stdin
%     out     - java.io.DataInputStream  for reading from the tool's stdout
%
%   The server is spawned lazily on the first call in this MATLAB
%   process (or worker) and kept alive as a `persistent` variable
%   thereafter, so subsequent encode/decode requests skip Python
%   startup entirely. When the MATLAB process exits, its stdin
%   handle closes, blosc_tool.py's `server` mode sees EOF and exits.
%
%   Each MATLAB process gets its own server: `persistent` scope is
%   per-process, and parpool workers are separate processes, so each
%   worker spawns one on first use and reuses it for the rest of its
%   lifetime. A pool with 18 workers doing an ingest that touches
%   thousands of source chunks spawns 19 Python processes total
%   (18 workers + the client), not thousands.
%
%   Not part of the stable API. If the server dies (Python crash,
%   OOM) a subsequent call detects it and respawns.

    persistent handle
    if ~isempty(handle) && isServerAlive(handle)
        h = handle;
        return;
    end

    pyExe = ndr.util.blosc.pythonExe();
    tool  = ndr.util.blosc.toolScript();
    if ~isfile(tool)
        error('ndr:util:blosc:serverConnect:ToolMissing', ...
            'blosc_tool.py not found at %s.', tool);
    end

    pb = java.lang.ProcessBuilder({pyExe, tool, 'server'});
    pb.redirectErrorStream(false);
    proc = pb.start();
    handle = struct( ...
        'process', proc, ...
        'in',      java.io.DataOutputStream(proc.getOutputStream()), ...
        'out',     java.io.DataInputStream(proc.getInputStream()));
    h = handle;
end

function tf = isServerAlive(h)
    tf = false;
    try
        tf = h.process.isAlive();
    catch
    end
end
