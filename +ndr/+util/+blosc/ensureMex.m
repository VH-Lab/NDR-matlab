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
%   Subsequent calls in the same process only re-check (cheaply, with
%   ndr.util.blosc.checkMexResolution) that blosc.encode still resolves
%   to a +blosc folder with its compiled MEX. If something removed the
%   install from the path since (a path reset, restoredefaultpath, a
%   test fixture restoring the path) or a +blosc copy without the MEX
%   (e.g. a source checkout) now shadows it, the install folder is
%   addpath'd again to the top. If that still does not win (e.g. the
%   stray copy is in the current folder), INFO.available is false and
%   INFO.reason names the shadowing folder.
%
%   Passing TRUE re-runs the install path even if +blosc is already
%   resolvable; useful for debugging.
%
%   Returns a struct with:
%     available - logical; true if blosc.encode (and encodeChunk,
%                 decode) resolve after this call to a +blosc folder
%                 that has private/blosc_mex.<mexext>.
%     version   - char; release tag installed, e.g. 'v0.2.1'.
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
    % v0.2.1: Linux MEX is linked with a non-executable stack. The
    % v0.2.0 mexa64 requests an executable stack and fails to load on
    % glibc >= 2.41 (Ubuntu 26.04+) with MATLAB:mex:ErrInvalidMEXFile
    % "cannot enable executable stack as shared object requires".
    BLOSC_MATLAB_VERSION = 'v0.2.1';

    persistent cached
    if ~force && ~isempty(cached) && cached.available
        % Hot path (called per batch/chunk): re-check the resolution
        % rather than trusting the cache; the path can change between
        % calls.
        resolution = ndr.util.blosc.checkMexResolution();
        if resolution.ok
            info = cached;
            return;
        end
        if isfolder(cached.path) && isfile(cached.mex)
            % The install is still on disk but no longer resolves:
            % put it back in front of whatever shadows it.
            moveToTopOfPath(cached.path);
            resolution = ndr.util.blosc.checkMexResolution();
            if resolution.ok
                info = cached;
                return;
            end
            % Keep CACHED as is so the next call retries cheaply.
            info = cached;
            info.available = false;
            info.reason = sprintf(['blosc-matlab is installed at %s ' ...
                'but is shadowed even after addpath: %s Falling back ' ...
                'to the Python one-shot tool.'], ...
                cached.path, resolution.reason);
            return;
        end
        % The cached install vanished from disk; reinstall below.
    end

    if ~force
        existingMex = discoverExistingMex(BLOSC_MATLAB_VERSION);
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

    moveToTopOfPath(cacheDir);
    resolution = ndr.util.blosc.checkMexResolution();

    info = struct( ...
        'available', resolution.ok, ...
        'version',   BLOSC_MATLAB_VERSION, ...
        'path',      cacheDir, ...
        'mex',       mexPath, ...
        'reason',    '');
    if ~info.available
        info.reason = sprintf(['addpath(%s) succeeded but blosc-matlab ' ...
            'still does not resolve to a copy with its MEX: %s ' ...
            'Falling back to the Python one-shot tool.'], ...
            cacheDir, resolution.reason);
    end
    cached = info;
end

function mexPath = discoverExistingMex(pinnedVersion)
%DISCOVEREXISTINGMEX - path to a usable blosc_mex already on the path.
%   Returns '' unless (a) the +blosc package is on the path, (b) it is
%   not a stale copy from an older version's cache folder under
%   prefdir()/blosc-matlab/, (c) its private/blosc_mex.<ext> exists,
%   AND (d) the v0.2.0-introduced wrapper blosc.encodeChunk is
%   resolvable. Check (d) forces a re-download when a user has a v0.1.0
%   install already on the path -- v0.1.0's MEX has no encode_chunk
%   verb. Check (b) does the same for an earlier ensureMex install of
%   a different pinned version (e.g. v0.2.0, whose Linux MEX cannot be
%   loaded on newer glibc): that folder is removed from the path so
%   the pinned version's folder, added later, is the one that
%   resolves.
    mexPath = '';
    encWrapper = which('blosc.encode');
    if isempty(encWrapper)
        return;
    end
    encFolder = fileparts(encWrapper);
    pkgRoot = fileparts(encFolder);
    cacheRoot = fullfile(prefdir(), 'blosc-matlab');
    % fileparts splits 'v0.2.0' into name 'v0' + ext '.2.0'; rejoin.
    [cacheParent, verName, verExt] = fileparts(pkgRoot);
    cacheVersion = [verName verExt];
    if strcmp(cacheParent, cacheRoot) && ~strcmp(cacheVersion, pinnedVersion)
        rmpath(pkgRoot);
        % Another stale copy could still be on the path; look again.
        mexPath = discoverExistingMex(pinnedVersion);
        return;
    end
    % Every wrapper NDR calls (including the v0.2.0 marker
    % encodeChunk, which v0.1.0 lacks) must resolve next to the MEX.
    resolution = ndr.util.blosc.checkMexResolution();
    if ~resolution.ok
        return;
    end
    mexPath = fullfile(encFolder, 'private', ['blosc_mex.' mexext]);
end

function moveToTopOfPath(folder)
%MOVETOTOPOFPATH - put FOLDER first on the MATLAB path.
%   addpath does not move a folder that is already on the path, so a
%   +blosc copy added later would keep shadowing it. Remove it first.
    if any(strcmp(folder, strsplit(path(), pathsep)))
        rmpath(folder);
    end
    addpath(folder, '-begin');
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
