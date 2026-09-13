function info = ensureMex(force)
% ndr.util.blosc.ensureMex - install the blosc-matlab MEX on first call.
%
%   INFO = ndr.util.blosc.ensureMex()
%   INFO = ndr.util.blosc.ensureMex(TRUE)
%
%   Ensures the blosc-matlab package (a MEX-backed +blosc/) is on this
%   MATLAB process's path. On the first call in a process (or worker),
%   downloads the pinned prebuilt tarball from the blosc-matlab
%   GitHub release for this platform, extracts it to a per-user cache
%   directory under prefdir(), and addpath's the extracted folder.
%   Subsequent calls in the same process are a no-op.
%
%   Passing TRUE re-runs the install path even if +blosc is already
%   resolvable; useful for debugging.
%
%   Returns a struct with:
%     available - logical; true if blosc.encode is resolvable after
%                 this call.
%     version   - char; release tag installed, e.g. 'v0.1.0'.
%     path      - char; folder added to the MATLAB path.
%     mex       - char; full path to the installed MEX file.
%     reason    - char; empty on success, otherwise a diagnostic
%                 explaining why MEX is not available (no prebuilt
%                 for this platform, download failed, ...).
%
%   The bootstrap never errors: if the platform has no prebuilt (Linux
%   arm64, macOS Intel) or the download fails, INFO.available is false
%   and INFO.reason names the cause. Callers should check
%   INFO.available and fall through to the Python-based path.
%
%   The pinned version and repo are set in the local constants below.
%   Bumping BLOSC_MATLAB_VERSION forces every NDR worker to re-fetch
%   the tarball on next call.

    arguments
        force (1,1) logical = false
    end

    BLOSC_MATLAB_REPO    = 'Waltham-Data-Science/blosc-matlab';
    BLOSC_MATLAB_VERSION = 'v0.2.0';

    persistent cached
    if ~force && ~isempty(cached) && cached.available
        info = cached;
        return;
    end

    if ~force
        existingMex = discoverExistingMex();
        if ~isempty(existingMex)
            info = struct( ...
                'available', true, ...
                'version',   BLOSC_MATLAB_VERSION, ...
                'path',      fileparts(fileparts(fileparts(existingMex))), ...
                'mex',       existingMex, ...
                'reason',    '');
            cached = info;
            return;
        end
    end

    assetName = pickAssetName();
    if isempty(assetName)
        info = struct( ...
            'available', false, ...
            'version',   BLOSC_MATLAB_VERSION, ...
            'path',      '', ...
            'mex',       '', ...
            'reason',    sprintf(['No blosc-matlab prebuilt for ' ...
                'this platform (mexext=%s). Falling back to the ' ...
                'Python one-shot tool.'], mexext));
        cached = info;
        return;
    end

    cacheDir = fullfile(prefdir(), 'blosc-matlab', BLOSC_MATLAB_VERSION);
    outDir   = fullfile(cacheDir, '+blosc', 'private');
    mexPath  = fullfile(outDir, ['blosc_mex.' mexext]);

    if force || ~isfile(mexPath)
        try
            downloadAndExtract(BLOSC_MATLAB_REPO, ...
                BLOSC_MATLAB_VERSION, assetName, cacheDir);
        catch ME
            info = struct( ...
                'available', false, ...
                'version',   BLOSC_MATLAB_VERSION, ...
                'path',      '', ...
                'mex',       '', ...
                'reason',    sprintf(['blosc-matlab %s could not be ' ...
                    'downloaded/extracted: %s. Falling back to the ' ...
                    'Python one-shot tool.'], ...
                    BLOSC_MATLAB_VERSION, ME.message));
            cached = info;
            return;
        end
    end

    if ~isfile(mexPath)
        info = struct( ...
            'available', false, ...
            'version',   BLOSC_MATLAB_VERSION, ...
            'path',      '', ...
            'mex',       '', ...
            'reason',    sprintf(['Extraction of %s succeeded but ' ...
                'blosc_mex.%s is not at %s.'], ...
                assetName, mexext, mexPath));
        cached = info;
        return;
    end

    addpath(cacheDir);

    info = struct( ...
        'available', exist('blosc.encode', 'file') == 2, ...
        'version',   BLOSC_MATLAB_VERSION, ...
        'path',      cacheDir, ...
        'mex',       mexPath, ...
        'reason',    '');
    if ~info.available
        info.reason = sprintf(['addpath(%s) succeeded but ' ...
            'blosc.encode still does not resolve.'], cacheDir);
    end
    cached = info;
end

function mexPath = discoverExistingMex()
%DISCOVEREXISTINGMEX - path to a working v0.2.0 blosc_mex on the path.
%   Returns '' unless (a) the +blosc package is on the path, (b) its
%   private/blosc_mex.<ext> exists, AND (c) the v0.2.0-introduced
%   wrapper blosc.encodeChunk is resolvable. The last check is what
%   forces a re-download when a user has a stale v0.1.0 install
%   already on the path -- v0.1.0's MEX has no encode_chunk verb, so
%   calling blosc.encodeChunk would error.
    mexPath = '';
    encWrapper = which('blosc.encode');
    if isempty(encWrapper)
        return;
    end
    encFolder = fileparts(encWrapper);
    candidate = fullfile(encFolder, 'private', ['blosc_mex.' mexext]);
    if ~isfile(candidate)
        return;
    end
    % v0.2.0 marker: encodeChunk wrapper. Older installs lack it.
    if isempty(which('blosc.encodeChunk'))
        return;
    end
    mexPath = candidate;
end

function name = pickAssetName()
    switch mexext
        case 'mexmaca64'
            name = 'blosc-matlab-macos-arm64.tar.gz';
        case 'mexa64'
            arch = computer('arch');
            if contains(lower(arch), 'aarch64') || ...
               contains(lower(arch), 'arm')
                name = '';
            else
                name = 'blosc-matlab-linux-x64.tar.gz';
            end
        case 'mexw64'
            name = 'blosc-matlab-windows-x64.tar.gz';
        otherwise
            name = '';
    end
end

function downloadAndExtract(repo, tag, assetName, destRoot)
    if strcmpi(tag, 'latest')
        url = sprintf('https://github.com/%s/releases/latest/download/%s', ...
            repo, assetName);
    else
        url = sprintf('https://github.com/%s/releases/download/%s/%s', ...
            repo, tag, assetName);
    end

    tmpDir = fullfile(tempdir, ['ndr-blosc-fetch-' ...
        char(matlab.lang.internal.uuid())]);
    mkdir(tmpDir);
    cleaner = onCleanup(@() safeRmdir(tmpDir)); %#ok<NASGU>

    localTar = fullfile(tmpDir, assetName);
    websave(localTar, url);

    stageDir = fullfile(tmpDir, 'x');
    mkdir(stageDir);
    untar(localTar, stageDir);

    hits = dir(fullfile(stageDir, '**', ['blosc_mex.' mexext]));
    if isempty(hits)
        error('ndr:util:blosc:ensureMex:AssetMissing', ...
            'Downloaded %s but it does not contain blosc_mex.%s.', ...
            assetName, mexext);
    end
    srcMex = fullfile(hits(1).folder, hits(1).name);
    srcRoot = fileparts(fileparts(fileparts(srcMex)));

    if isfolder(destRoot)
        rmdir(destRoot, 's');
    end
    parent = fileparts(destRoot);
    if ~isempty(parent) && ~isfolder(parent)
        mkdir(parent);
    end
    movefile(srcRoot, destRoot);
end

function safeRmdir(d)
    try %#ok<TRYNC>
        rmdir(d, 's');
    end
end
