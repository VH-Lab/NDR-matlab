function channels = listChannels(rootDir)
% ndr.format.smartspim.listChannels - enumerate SmartSPIM channels
%
%   CHANNELS = ndr.format.smartspim.LISTCHANNELS(ROOTDIR)
%
%   Enumerates the channel directories under ROOTDIR whose names match
%   "Ex_<laser>_Em_<filter>_Ch<channel>" and returns a struct array with
%   one entry per channel. Some versions of the SmartSPIM software name a
%   single-channel acquisition's folder "Ex_<laser>_Em_<filter>", with no
%   "_Ch<channel>"; that is accepted when it is the only channel folder
%   (filterChannel is then NaN). Several channel folders without
%   "_Ch<channel>" are refused (error
%   ndr:format:smartspim:listChannels:UnnumberedChannels): nothing then
%   says which All_Channels "_ch<k>" slices are whose, and a guess could
%   swap two channels unnoticed.
%
%     name             char, directory name (e.g. "Ex_561_Em_561F_Ch2")
%     wavelength       double, excitation wavelength (nm)
%     filterName       char, emission filter identifier (e.g. "561F")
%     filterChannel    double, hardware filter channel number
%     laserPowerLeft   double, left-side laser power percent, NaN if unknown
%     laserPowerRight  double, right-side laser power percent, NaN if unknown
%     numTiles         double, tile count from metadata.json (NaN if
%                      metadata.json does not enumerate tiles)
%
%   Discovery walks the filesystem for directories matching the naming
%   convention. metadata.json is consulted for laser power and per-channel
%   tile counts; missing metadata is tolerated (laser powers come back
%   NaN, numTiles comes back NaN) so the function stays useful on
%   partially-baked or hand-edited acquisitions.
%
%   The returned entries are sorted alphabetically by name for a stable
%   listing.
%
%   Errors if ROOTDIR does not exist or contains no channel directories.

    if isstring(rootDir) && isscalar(rootDir)
        rootDir = char(rootDir);
    end
    if ~(ischar(rootDir) && ~isempty(rootDir))
        error('ndr:format:smartspim:listChannels:BadInput', ...
            'rootDir must be a non-empty char or scalar string.');
    end
    if ~isfolder(rootDir)
        error('ndr:format:smartspim:listChannels:NotADirectory', ...
            'Not a directory: %s', rootDir);
    end

    entries = dir(rootDir);
    names = {};
    for i = 1:numel(entries)
        e = entries(i);
        if ~e.isdir
            continue;
        end
        % "Ex_<laser>_Em_<filter>_Ch<n>", or "Ex_<laser>_Em_<filter>" (a
        % filter name without underscores, so _MIP, _stitched and other
        % working folders are not taken for channels).
        if ~isempty(regexp(e.name, '^Ex_\d+_Em_(\w+_Ch\d+|[A-Za-z0-9]+)$', 'once'))
            names{end+1} = e.name; %#ok<AGROW>
        end
    end
    if isempty(names)
        error('ndr:format:smartspim:listChannels:NoChannels', ...
            'No channel directories (Ex_*_Em_*_Ch*) found in %s', rootDir);
    end
    names = sort(names);
    unnumbered = cellfun(@isempty, regexp(names, '_Ch\d+$', 'once'));
    if any(unnumbered) && numel(names) > 1
        error('ndr:format:smartspim:listChannels:UnnumberedChannels', ...
            ['%s has %d channel folders (%s), and %s no "_Ch<n>" filter-channel ' ...
             'number, so which All_Channels "_ch<k>" slices belong to which ' ...
             'channel is not known. Only a single channel folder may omit ' ...
             '"_Ch<n>".'], rootDir, numel(names), strjoin(names, ', '), ...
            pluralNot(sum(unnumbered)));
    end

    laserByWavelength = struct();
    numTilesByName = struct();
    metaPath = fullfile(rootDir, 'metadata.json');
    if isfile(metaPath)
        try
            meta = ndr.format.smartspim.readAcquisitionMetadata(rootDir);
            for j = 1:numel(meta.laserPower)
                lp = meta.laserPower(j);
                if isnan(lp.wavelength)
                    continue;
                end
                key = laserKey(lp.wavelength);
                laserByWavelength.(key) = lp;
            end
            for j = 1:numel(meta.tiles)
                t = meta.tiles(j);
                if isempty(t.channelName)
                    continue;
                end
                if isfield(numTilesByName, matlab.lang.makeValidName(t.channelName))
                    numTilesByName.(matlab.lang.makeValidName(t.channelName)) = ...
                        numTilesByName.(matlab.lang.makeValidName(t.channelName)) + 1;
                else
                    numTilesByName.(matlab.lang.makeValidName(t.channelName)) = 1;
                end
            end
        catch
            % metadata.json unreadable; leave lookups empty.
            laserByWavelength = struct();
            numTilesByName = struct();
        end
    end

    channels = struct('name', {}, 'wavelength', {}, 'filterName', {}, ...
        'filterChannel', {}, 'laserPowerLeft', {}, 'laserPowerRight', {}, ...
        'numTiles', {});

    for i = 1:numel(names)
        [wavelength, filterName, filterChannel] = parseChannelName(names{i});

        leftPct  = NaN;
        rightPct = NaN;
        key = laserKey(wavelength);
        if isfield(laserByWavelength, key)
            lp = laserByWavelength.(key);
            leftPct  = lp.leftPct;
            rightPct = lp.rightPct;
        end

        tileKey = matlab.lang.makeValidName(names{i});
        if isfield(numTilesByName, tileKey)
            n = numTilesByName.(tileKey);
        elseif isnan(filterChannel)
            % An unnumbered (single) channel folder: count the tiles of its
            % laser and filter, whatever filter channel metadata.json gives.
            n = countTiles(rootDir, wavelength, filterName);
        else
            n = NaN;
        end

        channels(i) = struct( ...
            'name',            names{i}, ...
            'wavelength',      wavelength, ...
            'filterName',      filterName, ...
            'filterChannel',   filterChannel, ...
            'laserPowerLeft',  leftPct, ...
            'laserPowerRight', rightPct, ...
            'numTiles',        n);
    end
end

function [wavelength, filterName, filterChannel] = parseChannelName(name)
    tok = regexp(name, '^Ex_(\d+)_Em_(.+)_Ch(\d+)$', 'tokens', 'once');
    if ~isempty(tok)
        wavelength    = str2double(tok{1});
        filterName    = tok{2};
        filterChannel = str2double(tok{3});
        return
    end
    tok = regexp(name, '^Ex_(\d+)_Em_([A-Za-z0-9]+)$', 'tokens', 'once');
    if isempty(tok)
        error('ndr:format:smartspim:listChannels:BadChannelName', ...
            ['Cannot parse channel name "%s"; expected "Ex_<n>_Em_<f>_Ch<n>" ' ...
             '(or "Ex_<n>_Em_<f>" for a single channel).'], name);
    end
    wavelength    = str2double(tok{1});
    filterName    = tok{2};
    filterChannel = NaN;
end

function n = countTiles(rootDir, wavelength, filterName)
    n = NaN;
    try
        meta = ndr.format.smartspim.readAcquisitionMetadata(rootDir);
        t = meta.tiles;
        if ~isempty(t)
            n = sum([t.laser] == wavelength & strcmp({t.filter}, filterName));
            if n == 0, n = NaN; end
        end
    catch
    end
end

function s = pluralNot(n)
    if n == 1
        s = 'one has';
    else
        s = sprintf('%d have', n);
    end
end

function k = laserKey(wavelength)
    k = sprintf('w%d', round(double(wavelength)));
end
