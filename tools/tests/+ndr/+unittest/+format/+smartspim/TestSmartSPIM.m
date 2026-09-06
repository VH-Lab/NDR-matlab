classdef TestSmartSPIM < matlab.unittest.TestCase
    % TestSmartSPIM - format layer for +ndr/+format/+smartspim
    %
    % The fixture is built by
    % ndr.test.format.smartspim.makeExampleFixture: a synthetic
    % 2-channel, 2-tile-per-channel acquisition tree with 4-slice
    % 8x10 uint16 TIFFs, JSON, and TeraStitcher XML sidecars. No
    % pre-built binaries are committed to the repo; imwrite writes the
    % TIFFs at test setup.
    %
    % Layout under BOTTOM/:
    %   Ex_561_Em_561F_Ch2/
    %     xml_import.xml           (import ABS_V/H: nominal)
    %     xml_merging.xml          (merging ABS_V/H: refined by a few px)
    %     100000/100000_200000/*.tiff  (row 0, col 0)
    %     100000/100000_300000/*.tiff  (row 1, col 0)
    %   Ex_640_Em_640F_Ch3/  (same layout as above)
    %   metadata.json
    %   sequence.json
    %
    % No toolbox is required to run these tests. imread/imwrite/imfinfo
    % handle TIFF in base MATLAB.

    properties
        FixtureDir
    end

    methods (TestMethodSetup)
        function makeFixture(testCase)
            testCase.FixtureDir = ndr.test.format.smartspim.makeExampleFixture();
            testCase.addTeardown(@() safeRmdir(testCase.FixtureDir));
        end
    end

    methods (Test)
        % ----- isSmartSPIM ------------------------------------------------
        function testIsSmartSPIMTrueForFixture(testCase)
            testCase.verifyTrue( ...
                ndr.format.smartspim.isSmartSPIM(testCase.FixtureDir));
        end

        function testIsSmartSPIMFalseForNonexistent(testCase)
            testCase.verifyFalse( ...
                ndr.format.smartspim.isSmartSPIM(tempname));
        end

        function testIsSmartSPIMFalseForEmptyDirectory(testCase)
            emptyDir = tempname;
            mkdir(emptyDir);
            testCase.addTeardown(@() rmdir(emptyDir, 's'));
            testCase.verifyFalse( ...
                ndr.format.smartspim.isSmartSPIM(emptyDir));
        end

        function testIsSmartSPIMFalseWithoutMetadata(testCase)
            delete(fullfile(testCase.FixtureDir, 'metadata.json'));
            testCase.verifyFalse( ...
                ndr.format.smartspim.isSmartSPIM(testCase.FixtureDir));
        end

        % ----- readAcquisitionMetadata ------------------------------------
        function testReadMetadataScalarFields(testCase)
            meta = ndr.format.smartspim.readAcquisitionMetadata( ...
                testCase.FixtureDir);
            testCase.verifyEqual(meta.acquisitionID, 'test_acquisition_001');
            testCase.verifyEqual(meta.objective, 'LCT 1.625x');
            testCase.verifyEqual(meta.umPerPix, 4);
            testCase.verifyEqual(meta.zStepUm, 4);
            testCase.verifyEqual(meta.voxelSizeUm, [4 4 4]);
            testCase.verifyEqual(meta.horizontalResolution, 10);
            testCase.verifyEqual(meta.verticalResolution, 8);
            testCase.verifyEqual(meta.sensorShape, [8 10]);
        end

        function testReadMetadataLaserPower(testCase)
            meta = ndr.format.smartspim.readAcquisitionMetadata( ...
                testCase.FixtureDir);
            testCase.verifyEqual(numel(meta.laserPower), 2);
            wavelengths = [meta.laserPower.wavelength];
            testCase.verifyTrue(any(wavelengths == 561));
            testCase.verifyTrue(any(wavelengths == 640));
            for i = 1:numel(meta.laserPower)
                lp = meta.laserPower(i);
                if lp.wavelength == 561
                    testCase.verifyEqual(lp.leftPct, 45);
                    testCase.verifyEqual(lp.rightPct, 45);
                elseif lp.wavelength == 640
                    testCase.verifyEqual(lp.leftPct, 40);
                    testCase.verifyEqual(lp.rightPct, 40);
                end
            end
        end

        function testReadMetadataTiles(testCase)
            meta = ndr.format.smartspim.readAcquisitionMetadata( ...
                testCase.FixtureDir);
            testCase.verifyEqual(numel(meta.tiles), 4);
            names = {meta.tiles.channelName};
            testCase.verifyEqual(sum(strcmp(names, 'Ex_561_Em_561F_Ch2')), 2);
            testCase.verifyEqual(sum(strcmp(names, 'Ex_640_Em_640F_Ch3')), 2);
            for i = 1:numel(meta.tiles)
                testCase.verifyEqual(meta.tiles(i).numImages, 4);
            end
        end

        function testReadMetadataSequenceFields(testCase)
            meta = ndr.format.smartspim.readAcquisitionMetadata( ...
                testCase.FixtureDir);
            testCase.verifyNotEmpty(meta.sequence);
            testCase.verifyEqual(meta.sequence.objective, 'LCT 1.625x');
            testCase.verifyEqual(meta.sequence.immersion, '1.52+');
            testCase.verifyEqual(meta.sequence.name, 'test_acquisition');
            testCase.verifyEqual(meta.sequence.zStepUm, 4);
            testCase.verifyEqual(meta.sequence.zTopUm, -100);
            testCase.verifyEqual(meta.sequence.zBottomUm, 100);
            testCase.verifyEqual(numel(meta.sequence.imagingSteps), 2);
            testCase.verifyEqual(meta.sequence.imagingSteps(1).laser, 561);
            testCase.verifyEqual(meta.sequence.imagingSteps(2).laser, 640);
            testCase.verifyEqual(numel(meta.sequence.laserPower), 2);
        end

        function testReadMetadataMissingSequenceIsOk(testCase)
            delete(fullfile(testCase.FixtureDir, 'sequence.json'));
            meta = ndr.format.smartspim.readAcquisitionMetadata( ...
                testCase.FixtureDir);
            testCase.verifyEmpty(meta.sequence);
        end

        function testReadMetadataErrorsOnMissingFile(testCase)
            delete(fullfile(testCase.FixtureDir, 'metadata.json'));
            testCase.verifyError( ...
                @() ndr.format.smartspim.readAcquisitionMetadata( ...
                    testCase.FixtureDir), ...
                'ndr:format:smartspim:readAcquisitionMetadata:MissingMetadata');
        end

        function testReadMetadataErrorsOnMissingField(testCase)
            metaPath = fullfile(testCase.FixtureDir, 'metadata.json');
            raw = fileread(metaPath);
            s = jsondecode(raw);
            s.sample_metadata = rmfield(s.sample_metadata, 'um_per_pix');
            fid = fopen(metaPath, 'w');
            fwrite(fid, jsonencode(s), 'char');
            fclose(fid);
            testCase.verifyError( ...
                @() ndr.format.smartspim.readAcquisitionMetadata( ...
                    testCase.FixtureDir), ...
                'ndr:format:smartspim:readAcquisitionMetadata:MissingField');
        end

        % ----- listChannels -----------------------------------------------
        function testListChannelsSortedByName(testCase)
            channels = ndr.format.smartspim.listChannels(testCase.FixtureDir);
            testCase.verifyEqual(numel(channels), 2);
            testCase.verifyEqual(channels(1).name, 'Ex_561_Em_561F_Ch2');
            testCase.verifyEqual(channels(2).name, 'Ex_640_Em_640F_Ch3');
        end

        function testListChannelsWavelengthAndFilter(testCase)
            channels = ndr.format.smartspim.listChannels(testCase.FixtureDir);
            testCase.verifyEqual(channels(1).wavelength, 561);
            testCase.verifyEqual(channels(1).filterName, '561F');
            testCase.verifyEqual(channels(1).filterChannel, 2);
            testCase.verifyEqual(channels(2).wavelength, 640);
            testCase.verifyEqual(channels(2).filterName, '640F');
            testCase.verifyEqual(channels(2).filterChannel, 3);
        end

        function testListChannelsLaserPower(testCase)
            channels = ndr.format.smartspim.listChannels(testCase.FixtureDir);
            testCase.verifyEqual(channels(1).laserPowerLeft, 45);
            testCase.verifyEqual(channels(1).laserPowerRight, 45);
            testCase.verifyEqual(channels(2).laserPowerLeft, 40);
            testCase.verifyEqual(channels(2).laserPowerRight, 40);
        end

        function testListChannelsNumTiles(testCase)
            channels = ndr.format.smartspim.listChannels(testCase.FixtureDir);
            testCase.verifyEqual(channels(1).numTiles, 2);
            testCase.verifyEqual(channels(2).numTiles, 2);
        end

        function testListChannelsErrorsWhenNone(testCase)
            emptyDir = tempname;
            mkdir(emptyDir);
            testCase.addTeardown(@() rmdir(emptyDir, 's'));
            testCase.verifyError( ...
                @() ndr.format.smartspim.listChannels(emptyDir), ...
                'ndr:format:smartspim:listChannels:NoChannels');
        end

        % ----- listTiles --------------------------------------------------
        function testListTilesReturnsBothTiles(testCase)
            tiles = ndr.format.smartspim.listTiles(testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2');
            testCase.verifyEqual(numel(tiles), 2);
            ids = {tiles.id};
            testCase.verifyTrue(any(strcmp(ids, '100000/100000_200000')));
            testCase.verifyTrue(any(strcmp(ids, '100000/100000_300000')));
        end

        function testListTilesRowColMatchesXml(testCase)
            tiles = ndr.format.smartspim.listTiles(testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2');
            byId = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for i = 1:numel(tiles)
                byId(tiles(i).id) = tiles(i);
            end
            t0 = byId('100000/100000_200000');
            t1 = byId('100000/100000_300000');
            testCase.verifyEqual(t0.row, 0);
            testCase.verifyEqual(t0.col, 0);
            testCase.verifyEqual(t1.row, 1);
            testCase.verifyEqual(t1.col, 0);
        end

        function testListTilesNominalOffsetsUseImportXml(testCase)
            tiles = ndr.format.smartspim.listTiles(testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2');
            byId = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for i = 1:numel(tiles)
                byId(tiles(i).id) = tiles(i);
            end
            t0 = byId('100000/100000_200000');
            t1 = byId('100000/100000_300000');
            % ABS_V = 0 -> pixel (D,V,H) = (0, 0, 0); um = (0, 0, 0)
            testCase.verifyEqual(t0.nominalPixelOffset, [0 0 0]);
            testCase.verifyEqual(t0.nominalUmOffset, [0 0 0]);
            % ABS_V = 100 -> pixel (0, 100, 0); um = (0, 400, 0)
            testCase.verifyEqual(t1.nominalPixelOffset, [0 100 0]);
            testCase.verifyEqual(t1.nominalUmOffset, [0 400 0]);
        end

        function testListTilesStitchedOffsetsUseMergingXml(testCase)
            tiles = ndr.format.smartspim.listTiles(testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2');
            byId = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for i = 1:numel(tiles)
                byId(tiles(i).id) = tiles(i);
            end
            t0 = byId('100000/100000_200000');
            t1 = byId('100000/100000_300000');
            % Merging has small corrections: V=2, H=1 and V=98, H=3
            testCase.verifyEqual(t0.stitchedPixelOffset, [0 2 1]);
            testCase.verifyEqual(t0.stitchedUmOffset, [0 8 4]);
            testCase.verifyEqual(t1.stitchedPixelOffset, [0 98 3]);
            testCase.verifyEqual(t1.stitchedUmOffset, [0 392 12]);
        end

        function testListTilesStitchedEmptyWhenMergingXmlMissing(testCase)
            delete(fullfile(testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', 'xml_merging.xml'));
            tiles = ndr.format.smartspim.listTiles(testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2');
            for i = 1:numel(tiles)
                testCase.verifyEmpty(tiles(i).stitchedPixelOffset);
                testCase.verifyEmpty(tiles(i).stitchedUmOffset);
                testCase.verifyNotEmpty(tiles(i).nominalPixelOffset);
            end
        end

        function testListTilesErrorsOnMissingImportXml(testCase)
            delete(fullfile(testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', 'xml_import.xml'));
            testCase.verifyError( ...
                @() ndr.format.smartspim.listTiles( ...
                    testCase.FixtureDir, 'Ex_561_Em_561F_Ch2'), ...
                'ndr:format:smartspim:listTiles:MissingImportXml');
        end

        function testListTilesErrorsOnUnknownChannel(testCase)
            testCase.verifyError( ...
                @() ndr.format.smartspim.listTiles( ...
                    testCase.FixtureDir, 'Ex_999_Em_XXX_Ch9'), ...
                'ndr:format:smartspim:listTiles:NoSuchChannel');
        end

        % ----- readTileInfo -----------------------------------------------
        function testReadTileInfoShapeAndSlices(testCase)
            info = ndr.format.smartspim.readTileInfo(testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000');
            testCase.verifyEqual(info.numSlices, 4);
            testCase.verifyEqual(info.height, 8);
            testCase.verifyEqual(info.width, 10);
            testCase.verifyEqual(info.dtype, 'uint16');
            testCase.verifyEqual(numel(info.slicePaths), 4);
            for i = 1:numel(info.slicePaths)
                testCase.verifyTrue(isfile(info.slicePaths{i}));
            end
        end

        function testReadTileInfoSlicePathsSortedLexically(testCase)
            info = ndr.format.smartspim.readTileInfo(testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000');
            [~, names, ~] = cellfun(@fileparts, info.slicePaths, ...
                'UniformOutput', false);
            expected = {'000000'; '000001'; '000002'; '000003'};
            testCase.verifyEqual(names(:), expected);
        end

        function testReadTileInfoErrorsOnMissingTile(testCase)
            testCase.verifyError( ...
                @() ndr.format.smartspim.readTileInfo( ...
                    testCase.FixtureDir, 'Ex_561_Em_561F_Ch2', ...
                    '999999/999999_999999'), ...
                'ndr:format:smartspim:readTileInfo:NoSuchTile');
        end

        % ----- readTileVolume ---------------------------------------------
        function testReadTileVolumeFullVolume(testCase)
            v = ndr.format.smartspim.readTileVolume(testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000');
            testCase.verifyEqual(size(v), [4 8 10]);
            testCase.verifyEqual(class(v), 'uint16');
            % channel 1 (Ex_561...), z=0 -> pixel 100 + 0 = 100
            testCase.verifyEqual(v(1, 1, 1), uint16(100));
            % z=3 -> pixel 103
            testCase.verifyEqual(v(4, 1, 1), uint16(103));
        end

        function testReadTileVolumeSecondChannel(testCase)
            v = ndr.format.smartspim.readTileVolume(testCase.FixtureDir, ...
                'Ex_640_Em_640F_Ch3', '100000/100000_200000');
            % channel 2, z=0 -> pixel 200
            testCase.verifyEqual(v(1, 1, 1), uint16(200));
            % z=2 -> 202
            testCase.verifyEqual(v(3, 1, 1), uint16(202));
        end

        function testReadTileVolumeZRange(testCase)
            v = ndr.format.smartspim.readTileVolume(testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000', ...
                'ZRange', [2 3]);
            testCase.verifyEqual(size(v), [2 8 10]);
            testCase.verifyEqual(v(1, 1, 1), uint16(101));
            testCase.verifyEqual(v(2, 1, 1), uint16(102));
        end

        function testReadTileVolumeBadZRange(testCase)
            testCase.verifyError( ...
                @() ndr.format.smartspim.readTileVolume( ...
                    testCase.FixtureDir, 'Ex_561_Em_561F_Ch2', ...
                    '100000/100000_200000', 'ZRange', [0 3]), ...
                'ndr:format:smartspim:readTileVolume:BadZRange');
            testCase.verifyError( ...
                @() ndr.format.smartspim.readTileVolume( ...
                    testCase.FixtureDir, 'Ex_561_Em_561F_Ch2', ...
                    '100000/100000_200000', 'ZRange', [1 99]), ...
                'ndr:format:smartspim:readTileVolume:BadZRange');
        end

        % ----- readStitcherXml (safe DTD handling) -----------------------
        function testReadStitcherXmlIgnoresMissingDtd(testCase)
            % The vendor XML references an external "TeraStitcher.DTD"
            % that is not present on disk. The parser must not fail
            % trying to resolve it; strip-DOCTYPE-then-parse is the
            % guarantee.
            xml = ndr.format.smartspim.readStitcherXml(fullfile( ...
                testCase.FixtureDir, 'Ex_561_Em_561F_Ch2', ...
                'xml_import.xml'));
            testCase.verifyEqual(xml.voxelDims.V, 4);
            testCase.verifyEqual(xml.dimensions.stackRows, 2);
            testCase.verifyEqual(numel(xml.stacks), 2);
        end
    end
end

function safeRmdir(d)
    if ~isempty(d) && isfolder(d)
        rmdir(d, 's');
    end
end
