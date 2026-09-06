function meta = readAcquisitionMetadata(rootDir)
% ndr.format.smartspim.readAcquisitionMetadata - parse SmartSPIM acquisition metadata
%
%   META = ndr.format.smartspim.READACQUISITIONMETADATA(ROOTDIR)
%
%   Parses ROOTDIR/metadata.json (required) and ROOTDIR/sequence.json
%   (optional) and returns their contents as a struct with the following
%   fields:
%
%     acquisitionID        char, session identifier from sample_metadata
%     objective            char, objective lens identifier
%     umPerPix             double, lateral pixel size (micrometers)
%     zStepUm              double, z-step between slices (micrometers)
%     voxelSizeUm          1x3 double [z y x] in micrometers
%     horizontalResolution double, camera sensor width (pixels)
%     verticalResolution   double, camera sensor height (pixels)
%     sensorShape          1x2 double [height width] in pixels
%     zRange               double, total z travel in micrometers
%     scanning             char, scan mode
%     destripe             char, destripe filter parameters
%     destripeStatus       char, whether destripe was applied
%     laserPower           struct array with fields:
%                             wavelength, leftPct, rightPct
%     tiles                struct array (one entry per acquired tile) with:
%                             X, Y, Z          (char, stage positions in
%                                               0.1 um units, as written
%                                               in the source JSON)
%                             laser            (double, excitation wavelength nm)
%                             side             (double, 0=left/1=right, NaN if absent)
%                             exposure         (double, exposure ms, NaN if absent)
%                             filter           (char, emission filter name)
%                             filterChannel    (double)
%                             numImages        (double, z-slice count)
%                             channelName      (char, "Ex_<laser>_Em_<filter>_Ch<ch>")
%     sequence             struct with the contents of sequence.json, or
%                          [] if that file is absent. When present, its
%                          fields are:
%                             objective, immersion, name  (char)
%                             zStepUm, zTopUm, zBottomUm  (double)
%                             imagingSteps  struct array with fields laser, filter
%                             laserPower    struct array (same layout as top-level)
%                             tileBoundary  struct or []
%                             focusPoints   cell array of structs (may be
%                                           empty if the file omits them)
%
%   Errors if metadata.json is missing, unparseable, or missing required
%   fields (sample_metadata, um_per_pix, z_step_um). Errors if
%   sequence.json is present but malformed (missing steps or z section).

    if isstring(rootDir) && isscalar(rootDir)
        rootDir = char(rootDir);
    end
    if ~(ischar(rootDir) && ~isempty(rootDir))
        error('ndr:format:smartspim:readAcquisitionMetadata:BadInput', ...
            'rootDir must be a non-empty char or scalar string.');
    end
    if ~isfolder(rootDir)
        error('ndr:format:smartspim:readAcquisitionMetadata:NotADirectory', ...
            'Not a directory: %s', rootDir);
    end

    metaPath = fullfile(rootDir, 'metadata.json');
    if ~isfile(metaPath)
        error('ndr:format:smartspim:readAcquisitionMetadata:MissingMetadata', ...
            'metadata.json not found in %s', rootDir);
    end

    try
        rawMeta = fileread(metaPath);
        rawStruct = jsondecode(rawMeta);
    catch ME
        error('ndr:format:smartspim:readAcquisitionMetadata:InvalidJSON', ...
            'Failed to parse %s as JSON: %s', metaPath, ME.message);
    end

    if ~isfield(rawStruct, 'sample_metadata')
        error('ndr:format:smartspim:readAcquisitionMetadata:MissingSampleMetadata', ...
            'metadata.json is missing "sample_metadata": %s', metaPath);
    end
    sm = rawStruct.sample_metadata;

    for reqField = {'um_per_pix', 'z_step_um'}
        if ~isfield(sm, reqField{1})
            error('ndr:format:smartspim:readAcquisitionMetadata:MissingField', ...
                'sample_metadata is missing required field "%s": %s', ...
                reqField{1}, metaPath);
        end
    end

    meta = struct();
    meta.acquisitionID        = charField(sm, 'acquisition_ID', '');
    meta.objective            = charField(sm, 'objective', '');
    meta.umPerPix             = double(sm.um_per_pix);
    meta.zStepUm              = double(sm.z_step_um);
    meta.voxelSizeUm          = [meta.zStepUm meta.umPerPix meta.umPerPix];
    meta.horizontalResolution = numericField(sm, 'horizontal_resolution', NaN);
    meta.verticalResolution   = numericField(sm, 'vertical_resolution', NaN);
    if isnan(meta.horizontalResolution) || isnan(meta.verticalResolution)
        meta.sensorShape = [NaN NaN];
    else
        meta.sensorShape = [meta.verticalResolution meta.horizontalResolution];
    end
    meta.zRange         = numericField(sm, 'z_range', NaN);
    meta.scanning       = charField(sm, 'scanning', '');
    meta.destripe       = charField(sm, 'destripe', '');
    meta.destripeStatus = charField(sm, 'destripe_status', '');

    laserRaw = findFieldByPrefix(sm, 'laser');
    meta.laserPower = parseLaserPower(laserRaw);

    tilesRaw = getFieldSafe(rawStruct, 'tiles', []);
    meta.tiles = parseTiles(tilesRaw);

    seqPath = fullfile(rootDir, 'sequence.json');
    if isfile(seqPath)
        try
            rawSeq = fileread(seqPath);
            seqStruct = jsondecode(rawSeq);
        catch ME
            error('ndr:format:smartspim:readAcquisitionMetadata:InvalidJSON', ...
                'Failed to parse %s as JSON: %s', seqPath, ME.message);
        end
        meta.sequence = parseSequence(seqStruct, seqPath);
    else
        meta.sequence = [];
    end
end

function v = getFieldSafe(s, name, defaultValue)
    if isstruct(s) && isfield(s, name)
        v = s.(name);
    else
        v = defaultValue;
    end
end

function v = findFieldByPrefix(s, prefixLower)
    % Case-insensitive prefix match against fieldnames(s); handy for JSON
    % keys mangled by jsondecode (e.g. "laser power" -> "laser_power",
    % "laserPower" -> "laserPower"). Returns [] if no match.
    v = [];
    if ~isstruct(s)
        return;
    end
    fn = fieldnames(s);
    for i = 1:numel(fn)
        if numel(fn{i}) >= numel(prefixLower) && ...
                strcmpi(fn{i}(1:numel(prefixLower)), prefixLower)
            v = s.(fn{i});
            return;
        end
    end
end

function c = charField(s, name, defaultValue)
    if ~isstruct(s) || ~isfield(s, name)
        c = defaultValue;
        return;
    end
    c = coerceChar(s.(name));
    if isempty(c)
        c = defaultValue;
    end
end

function n = numericField(s, name, defaultValue)
    if ~isstruct(s) || ~isfield(s, name)
        n = defaultValue;
        return;
    end
    n = numericFromAny(s.(name));
    if isnan(n)
        n = defaultValue;
    end
end

function d = numericFromAny(v)
    if isempty(v)
        d = NaN;
    elseif isnumeric(v) && isscalar(v)
        d = double(v);
    elseif ischar(v) || (isstring(v) && isscalar(v))
        d = str2double(char(v));
    else
        d = NaN;
    end
end

function c = coerceChar(v)
    if isempty(v)
        c = '';
    elseif ischar(v)
        c = v;
    elseif isstring(v) && isscalar(v)
        c = char(v);
    elseif isnumeric(v) && isscalar(v)
        c = num2str(v);
    else
        c = '';
    end
end

function out = coerceCellArray(v)
    if iscell(v)
        out = v(:).';
    elseif isstruct(v)
        out = cell(1, numel(v));
        for i = 1:numel(v)
            out{i} = v(i);
        end
    else
        out = {v};
    end
end

function out = parseLaserPower(raw)
    out = struct('wavelength', {}, 'leftPct', {}, 'rightPct', {});
    if isempty(raw)
        return;
    end
    entries = coerceCellArray(raw);
    for i = 1:numel(entries)
        e = entries{i};
        if ~isstruct(e)
            continue;
        end
        out(end+1) = struct( ...
            'wavelength', numericFromAny(getFieldSafe(e, 'wavelength', NaN)), ...
            'leftPct',    numericFromAny(findFieldByPrefix(e, 'left')), ...
            'rightPct',   numericFromAny(findFieldByPrefix(e, 'right'))); %#ok<AGROW>
    end
end

function out = parseTiles(raw)
    out = struct('X', {}, 'Y', {}, 'Z', {}, 'laser', {}, 'side', {}, ...
        'exposure', {}, 'filter', {}, 'filterChannel', {}, ...
        'numImages', {}, 'channelName', {});
    if isempty(raw)
        return;
    end
    entries = coerceCellArray(raw);
    for i = 1:numel(entries)
        t = entries{i};
        if ~isstruct(t)
            continue;
        end
        laser  = numericFromAny(getFieldSafe(t, 'Laser', NaN));
        filt   = coerceChar(getFieldSafe(t, 'Filter', ''));
        fch    = numericFromAny(getFieldSafe(t, 'FilterChannel', NaN));
        chName = '';
        if ~isnan(laser) && ~isempty(filt) && ~isnan(fch)
            chName = sprintf('Ex_%g_Em_%s_Ch%g', laser, filt, fch);
        end
        out(end+1) = struct( ...
            'X',             coerceChar(getFieldSafe(t, 'X', '')), ...
            'Y',             coerceChar(getFieldSafe(t, 'Y', '')), ...
            'Z',             coerceChar(getFieldSafe(t, 'Z', '')), ...
            'laser',         laser, ...
            'side',          numericFromAny(getFieldSafe(t, 'Side', NaN)), ...
            'exposure',      numericFromAny(getFieldSafe(t, 'Exposure', NaN)), ...
            'filter',        filt, ...
            'filterChannel', fch, ...
            'numImages',     numericFromAny(getFieldSafe(t, 'NumImages', NaN)), ...
            'channelName',   chName); %#ok<AGROW>
    end
end

function out = parseSequence(seqStruct, seqPath)
    steps = getFieldSafe(seqStruct, 'steps', []);
    if isempty(steps)
        error('ndr:format:smartspim:readAcquisitionMetadata:MissingSteps', ...
            'sequence.json is missing "steps": %s', seqPath);
    end
    stepList = coerceCellArray(steps);
    step = stepList{1};

    z = getFieldSafe(step, 'z', []);
    if isempty(z) || ~isstruct(z)
        error('ndr:format:smartspim:readAcquisitionMetadata:MissingZSection', ...
            'sequence.json step is missing "z": %s', seqPath);
    end

    imagingRaw = findFieldByPrefix(step, 'imaging');
    imagingSteps = struct('laser', {}, 'filter', {});
    if ~isempty(imagingRaw)
        imagingCells = coerceCellArray(imagingRaw);
        for i = 1:numel(imagingCells)
            ci = imagingCells{i};
            imagingSteps(end+1) = struct( ...
                'laser',  numericFromAny(getFieldSafe(ci, 'laser', NaN)), ...
                'filter', coerceChar(getFieldSafe(ci, 'filter', ''))); %#ok<AGROW>
        end
    end

    laserRaw = findFieldByPrefix(step, 'laser');

    tileBoundary = findFieldByPrefix(step, 'tile');
    if isempty(tileBoundary)
        tileBoundary = [];
    end

    focusPointsRaw = findFieldByPrefix(step, 'focus');
    if isempty(focusPointsRaw)
        focusPoints = {};
    else
        focusPoints = coerceCellArray(focusPointsRaw);
    end

    % Build field-by-field: struct() distributes cell values across a
    % struct array, which would fight the mix of struct-array and cell
    % values below.
    out = struct();
    out.objective    = charField(seqStruct, 'objective', '');
    out.immersion    = charField(seqStruct, 'immersion', '');
    out.name         = charField(step, 'name', '');
    out.zStepUm      = numericFromAny(findFieldByPrefix(z, 'step'));
    out.zTopUm       = numericFromAny(findFieldByPrefix(z, 'top'));
    out.zBottomUm    = numericFromAny(findFieldByPrefix(z, 'bottom'));
    out.imagingSteps = imagingSteps;
    out.laserPower   = parseLaserPower(laserRaw);
    out.tileBoundary = tileBoundary;
    out.focusPoints  = focusPoints;
end
