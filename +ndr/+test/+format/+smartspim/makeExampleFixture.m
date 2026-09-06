function fixtureDir = makeExampleFixture(parentDir)
% ndr.test.format.smartspim.makeExampleFixture - write a tiny SmartSPIM tree
%
%   FIXTUREDIR = ndr.test.format.smartspim.MAKEEXAMPLEFIXTURE()
%   FIXTUREDIR = ndr.test.format.smartspim.MAKEEXAMPLEFIXTURE(PARENTDIR)
%
%   Builds a synthetic SmartSPIM acquisition directory on disk that
%   mirrors the LifeCanvas layout documented in
%   ferret-lightsheet/formats/SmartSPIM.md: one root directory holding
%   metadata.json, sequence.json, and one "Ex_<laser>_Em_<filter>_Ch<n>"
%   channel directory per channel. Each channel folder holds
%   xml_import.xml, xml_merging.xml, and one tile directory per stack;
%   each tile directory holds a small stack of zero-padded 2D TIFF
%   z-slices.
%
%   Contents:
%     * 2 channels (Ex_561_Em_561F_Ch2, Ex_640_Em_640F_Ch3)
%     * 2 tiles per channel arranged as a 2x1 grid, sharing the same
%       (X, Y) stage positions across channels
%     * 4 z-slices per tile, 8x10 pixel synthetic uint16 images
%     * xml_merging.xml carries small 2-pixel corrections against
%       xml_import.xml so tests can distinguish nominal vs. stitched
%       offsets
%
%   PARENTDIR defaults to a fresh directory under tempdir. Returns the
%   root of the SmartSPIM acquisition on disk.
%
%   The synthetic pixel values encode (channelIndex, z) so tests can
%   verify that a read hits the right slice:
%     pixel_value(channelIndex, z) = 100 * channelIndex + z

    if nargin < 1 || isempty(parentDir)
        parentDir = tempname;
        mkdir(parentDir);
    end
    fixtureDir = fullfile(parentDir, 'BOTTOM');
    if isfolder(fixtureDir)
        rmdir(fixtureDir, 's');
    end
    mkdir(fixtureDir);

    numSlices = 4;
    height    = 8;
    width     = 10;
    voxelV    = 4;
    voxelH    = 4;
    voxelD    = 1;

    channels = { ...
        struct('name', 'Ex_561_Em_561F_Ch2', 'laser', 561, 'filter', '561F', 'chNum', 2, 'left', 45, 'right', 45), ...
        struct('name', 'Ex_640_Em_640F_Ch3', 'laser', 640, 'filter', '640F', 'chNum', 3, 'left', 40, 'right', 40) };

    stacksImport = { ...
        struct('row', 0, 'col', 0, 'absV',   0, 'absH', 0, 'absD', 0, 'dirName', '100000/100000_200000'), ...
        struct('row', 1, 'col', 0, 'absV', 100, 'absH', 0, 'absD', 0, 'dirName', '100000/100000_300000') };
    stacksMerging = { ...
        struct('row', 0, 'col', 0, 'absV',  2, 'absH', 1, 'absD', 0, 'dirName', '100000/100000_200000'), ...
        struct('row', 1, 'col', 0, 'absV', 98, 'absH', 3, 'absD', 0, 'dirName', '100000/100000_300000') };

    importXml = buildStitcherXml(stacksImport, voxelV, voxelH, voxelD, ...
        2, 1, numSlices);
    mergingXml = buildStitcherXml(stacksMerging, voxelV, voxelH, voxelD, ...
        2, 1, numSlices);

    for ci = 1:numel(channels)
        ch = channels{ci};
        chDir = fullfile(fixtureDir, ch.name);
        mkdir(chDir);
        writeTextFile(fullfile(chDir, 'xml_import.xml'), importXml);
        writeTextFile(fullfile(chDir, 'xml_merging.xml'), mergingXml);
        for si = 1:numel(stacksImport)
            s = stacksImport{si};
            tileDir = tileDirOnDisk(chDir, s.dirName);
            mkdirRecursive(tileDir);
            for z = 0:(numSlices - 1)
                img = uint16(100 * ci + z);
                img = repmat(img, height, width);
                sliceName = sprintf('%06d.tiff', z);
                imwrite(img, fullfile(tileDir, sliceName), 'tif');
            end
        end
    end

    writeJSON(fullfile(fixtureDir, 'metadata.json'), ...
        buildMetadata(channels, stacksImport, numSlices, height, width));
    writeJSON(fullfile(fixtureDir, 'sequence.json'), ...
        buildSequence(channels));
end

function xml = buildStitcherXml(stacks, voxelV, voxelH, voxelD, ...
        stackRows, stackCols, stackSlices)
    lines = cell(0, 1);
    lines{end+1} = '<?xml version="1.0" encoding="UTF-8" ?>';
    lines{end+1} = '<!DOCTYPE TeraStitcher SYSTEM "TeraStitcher.DTD">';
    lines{end+1} = '<TeraStitcher volume_format="TiledXY|2Dseries" input_plugin="tiff2D">';
    lines{end+1} = '    <stacks_dir value="." />';
    lines{end+1} = '    <mdata_bin value="./mdata.bin" />';
    lines{end+1} = '    <ref_sys ref1="2" ref2="1" ref3="3" />';
    lines{end+1} = sprintf('    <voxel_dims V="%g" H="%g" D="%g" />', voxelV, voxelH, voxelD);
    lines{end+1} = '    <origin V="0" H="0" D="0" />';
    lines{end+1} = '    <mechanical_displacements V="100" H="100" />';
    lines{end+1} = sprintf(...
        '    <dimensions stack_rows="%d" stack_columns="%d" stack_slices="%d" />', ...
        stackRows, stackCols, stackSlices);
    lines{end+1} = '    <STACKS>';
    for i = 1:numel(stacks)
        s = stacks{i};
        lines{end+1} = sprintf( ...
            ['        <Stack N_CHANS="1" N_BYTESxCHAN="2" ROW="%d" COL="%d" ' ...
             'ABS_V="%g" ABS_H="%g" ABS_D="%g" STITCHABLE="no" ' ...
             'DIR_NAME="%s" Z_RANGES="[0,%d)" IMG_REGEX="">'], ...
            s.row, s.col, s.absV, s.absH, s.absD, s.dirName, stackSlices); %#ok<AGROW>
        lines{end+1} = '            <NORTH_displacements />'; %#ok<AGROW>
        lines{end+1} = '            <EAST_displacements />'; %#ok<AGROW>
        lines{end+1} = '            <SOUTH_displacements />'; %#ok<AGROW>
        lines{end+1} = '            <WEST_displacements />'; %#ok<AGROW>
        lines{end+1} = '        </Stack>'; %#ok<AGROW>
    end
    lines{end+1} = '    </STACKS>';
    lines{end+1} = '</TeraStitcher>';
    xml = strjoin(lines, newline);
end

function meta = buildMetadata(channels, stacks, numSlices, height, width)
    laserPower = cell(1, numel(channels));
    for i = 1:numel(channels)
        ch = channels{i};
        laserPower{i} = struct( ...
            'wavelength', ch.laser, ...
            'left___',    ch.left, ...
            'right___',   ch.right);
    end
    tiles = {};
    for ci = 1:numel(channels)
        ch = channels{ci};
        for si = 1:numel(stacks)
            s = stacks{si};
            dirParts = strsplit(s.dirName, '/');
            xStr = dirParts{1};
            yStr = extractY(dirParts{2}, xStr);
            tiles{end+1} = struct( ...
                'X',             xStr, ...
                'Y',             yStr, ...
                'Z',             '-1000', ...
                'Laser',         num2str(ch.laser), ...
                'Side',          num2str(mod(si - 1, 2)), ...
                'Exposure',      '2', ...
                'Acquire',       '1', ...
                'Filter',        ch.filter, ...
                'FilterChannel', num2str(ch.chNum), ...
                'NumImages',     num2str(numSlices)); %#ok<AGROW>
        end
    end
    sampleMetadata = struct( ...
        'acquisition_ID',         'test_acquisition_001', ...
        'objective',              'LCT 1.625x', ...
        'um_per_pix',             4, ...
        'z_step_um',              4, ...
        'horizontal_resolution',  width, ...
        'vertical_resolution',    height, ...
        'z_range',                -100.0, ...
        'scanning',               'FAST', ...
        'destripe',               '256/0', ...
        'destripe_status',        'done');
    sampleMetadata.laser_power = laserPower;
    meta = struct('sample_metadata', sampleMetadata);
    meta.tiles = tiles;
end

function seq = buildSequence(channels)
    laserPower = cell(1, numel(channels));
    for i = 1:numel(channels)
        ch = channels{i};
        laserPower{i} = struct( ...
            'wavelength', ch.laser, ...
            'left___',    ch.left, ...
            'right___',   ch.right);
    end
    imagingSteps = cell(1, numel(channels));
    for i = 1:numel(channels)
        ch = channels{i};
        imagingSteps{i} = struct( ...
            'laser',  ch.laser, ...
            'filter', ch.filter);
    end
    zSection = struct( ...
        'step_size__um_',      4, ...
        'top__um_',            -100.0, ...
        'bottom__um_',         100.0, ...
        'default_step_size',   true);
    tileBoundary = struct( ...
        'top__pix_',              10.0, ...
        'left__pix_',             5.0, ...
        'bottom__pix_',           90.0, ...
        'right__pix_',            95.0, ...
        'left_right_split__pix_', 50.0);
    focusPoints = { struct( ...
        'objective',      'LCT 1.625x', ...
        'wavelength',     561, ...
        'z_position',     [-50 50], ...
        'focus_position', [-10 -12]) };
    step = struct( ...
        'GUID',           'TEST-GUID-0001', ...
        'name',           'test_acquisition', ...
        'disabled',       false, ...
        'destripe',       true, ...
        'z',              zSection);
    step.imaging_steps = imagingSteps;
    step.laser_power   = laserPower;
    step.tile_boundary = tileBoundary;
    step.focus_points  = focusPoints;
    seq = struct( ...
        'objective', 'LCT 1.625x', ...
        'immersion', '1.52+');
    seq.steps = {step};
end

function y = extractY(second, xStr)
    idx = strfind(second, [xStr '_']);
    if isempty(idx) || idx(1) ~= 1
        parts = strsplit(second, '_');
        y = parts{end};
    else
        y = second(numel(xStr) + 2:end);
    end
end

function tileDir = tileDirOnDisk(channelDir, dirName)
    parts = strsplit(dirName, '/');
    parts = parts(~cellfun('isempty', parts));
    tileDir = fullfile(channelDir, parts{:});
end

function mkdirRecursive(p)
    parent = fileparts(p);
    if ~isempty(parent) && ~isfolder(parent)
        mkdirRecursive(parent);
    end
    if ~isfolder(p)
        mkdir(p);
    end
end

function writeTextFile(path, txt)
    fid = fopen(path, 'w');
    if fid < 0
        error('ndr:test:format:smartspim:makeExampleFixture:OpenFailed', ...
            'Could not open %s for writing.', path);
    end
    cleanup = onCleanup(@() fclose(fid));
    fwrite(fid, txt, 'char');
end

function writeJSON(path, s)
    txt = jsonencode(s);
    writeTextFile(path, txt);
end
