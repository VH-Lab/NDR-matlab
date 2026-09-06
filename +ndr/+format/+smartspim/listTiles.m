function tiles = listTiles(rootDir, channelName)
% ndr.format.smartspim.listTiles - enumerate tiles for a SmartSPIM channel
%
%   TILES = ndr.format.smartspim.LISTTILES(ROOTDIR, CHANNELNAME)
%
%   Returns a struct array with one entry per tile in the given channel,
%   built from the channel's xml_import.xml (mandatory) and
%   xml_merging.xml (optional -- only present after stitching). Fields:
%
%     id                     char, the tile's DIR_NAME from the XML
%                            (e.g. "389960/389960_445310"). Always uses
%                            forward-slash separators regardless of
%                            filesystem; call fullfile to resolve on
%                            disk.
%     row                    double, tile grid row (0-indexed, from XML)
%     col                    double, tile grid column (0-indexed, from XML)
%     numSlices              double, z-slice count for this tile
%                            (from metadata.json when available; NaN
%                            otherwise)
%     nominalPixelOffset     1x3 double [d v h], from xml_import.xml
%                            (absolute tile offset in pixels, before
%                            stitch refinement)
%     nominalUmOffset        1x3 double [z y x] in micrometers
%                            (nominalPixelOffset .* voxelDims)
%     stitchedPixelOffset    1x3 double [d v h], from xml_merging.xml,
%                            or [] if the merging XML is not present or
%                            does not carry a matching stack
%     stitchedUmOffset       1x3 double [z y x] in micrometers, or []
%
%   The tile order mirrors xml_import.xml -- Stack elements as they
%   appear in the file. Callers who want a grid-shaped view should key
%   by (row, col).
%
%   Errors if the channel directory or its xml_import.xml cannot be
%   parsed. A missing xml_merging.xml is not an error -- stitched
%   offsets simply come back as [].

    if isstring(rootDir) && isscalar(rootDir)
        rootDir = char(rootDir);
    end
    if isstring(channelName) && isscalar(channelName)
        channelName = char(channelName);
    end
    if ~(ischar(rootDir) && ~isempty(rootDir))
        error('ndr:format:smartspim:listTiles:BadInput', ...
            'rootDir must be a non-empty char or scalar string.');
    end
    if ~(ischar(channelName) && ~isempty(channelName))
        error('ndr:format:smartspim:listTiles:BadInput', ...
            'channelName must be a non-empty char or scalar string.');
    end
    channelDir = fullfile(rootDir, channelName);
    if ~isfolder(channelDir)
        error('ndr:format:smartspim:listTiles:NoSuchChannel', ...
            'Channel directory not found: %s', channelDir);
    end

    importPath = fullfile(channelDir, 'xml_import.xml');
    if ~isfile(importPath)
        error('ndr:format:smartspim:listTiles:MissingImportXml', ...
            'xml_import.xml not found in %s', channelDir);
    end
    importXml = ndr.format.smartspim.readStitcherXml(importPath);

    mergingPath = fullfile(channelDir, 'xml_merging.xml');
    mergingByDir = struct();
    voxelDimsMerging = importXml.voxelDims;
    if isfile(mergingPath)
        mergingXml = ndr.format.smartspim.readStitcherXml(mergingPath);
        voxelDimsMerging = mergingXml.voxelDims;
        for k = 1:numel(mergingXml.stacks)
            s = mergingXml.stacks(k);
            key = dirNameKey(s.dirName);
            mergingByDir.(key) = s;
        end
    end

    numSlicesByDir = struct();
    metaPath = fullfile(rootDir, 'metadata.json');
    if isfile(metaPath)
        try
            meta = ndr.format.smartspim.readAcquisitionMetadata(rootDir);
            for j = 1:numel(meta.tiles)
                t = meta.tiles(j);
                if ~strcmp(t.channelName, channelName)
                    continue;
                end
                dn = sprintf('%s/%s_%s', t.X, t.X, t.Y);
                key = dirNameKey(dn);
                numSlicesByDir.(key) = t.numImages;
            end
        catch
            numSlicesByDir = struct();
        end
    end

    voxelImport = importXml.voxelDims;
    vI = [voxelImport.D voxelImport.V voxelImport.H];
    vM = [voxelDimsMerging.D voxelDimsMerging.V voxelDimsMerging.H];

    tiles = struct('id', {}, 'row', {}, 'col', {}, 'numSlices', {}, ...
        'nominalPixelOffset', {}, 'nominalUmOffset', {}, ...
        'stitchedPixelOffset', {}, 'stitchedUmOffset', {});

    for i = 1:numel(importXml.stacks)
        s = importXml.stacks(i);
        key = dirNameKey(s.dirName);

        if isfield(numSlicesByDir, key)
            n = numSlicesByDir.(key);
        else
            n = NaN;
        end

        nomPix = [s.absD s.absV s.absH];
        nomUm  = nomPix .* vI;

        if isfield(mergingByDir, key)
            m = mergingByDir.(key);
            stPix = [m.absD m.absV m.absH];
            stUm  = stPix .* vM;
        else
            stPix = [];
            stUm  = [];
        end

        tiles(i) = struct( ...
            'id',                  s.dirName, ...
            'row',                 s.row, ...
            'col',                 s.col, ...
            'numSlices',           n, ...
            'nominalPixelOffset',  nomPix, ...
            'nominalUmOffset',     nomUm, ...
            'stitchedPixelOffset', stPix, ...
            'stitchedUmOffset',    stUm);
    end
end

function k = dirNameKey(dirName)
    % Build a valid struct field name from a forward-slash tile path.
    k = matlab.lang.makeValidName(strrep(char(dirName), '/', '_'));
end
