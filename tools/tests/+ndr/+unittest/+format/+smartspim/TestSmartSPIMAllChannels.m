classdef TestSmartSPIMAllChannels < matlab.unittest.TestCase
    % TestSmartSPIMAllChannels - ndr.format.smartspim All_Channels functions
    %
    % Covers hasAllChannels, readAllChannelsInfo and readAllChannelsVolume
    % against the synthetic fixture with its All_Channels folder
    % (ndr.test.format.smartspim.makeExampleFixture('AllChannels', true)):
    % 2 channels x 4 slices of 106x13 uint16 LZW TIFFs, pixel value
    % 1000 * (k + 1) + z for file "_ch<k>", slice z (0-based).
    %
    % Channel mapping rules pinned here (ferret-lightsheet
    % formats/SmartSPIM.md section 6):
    %   * without <channel>_MIP_stitched, ch<k> is the rank of the
    %     filter-channel number (Ch2 -> ch0, Ch3 -> ch1);
    %   * a <channel>_MIP_stitched folder whose files share one _ch<k>
    %     suffix overrides the rank;
    %   * All_Channels counts as usable only when every channel has slices.

    properties
        FixtureDir
    end

    methods (TestMethodSetup)
        function makeFixture(testCase)
            testCase.FixtureDir = ndr.test.format.smartspim.makeExampleFixture( ...
                '', 'AllChannels', true);
            testCase.addTeardown(@() safeRmdir(testCase.FixtureDir));
        end
    end

    methods (Test)

        function testHasAllChannelsTrue(testCase)
            testCase.verifyTrue(ndr.format.smartspim.hasAllChannels(testCase.FixtureDir));
        end

        function testHasAllChannelsFalseWithoutFolder(testCase)
            rmdir(fullfile(testCase.FixtureDir, 'All_Channels'), 's');
            testCase.verifyFalse(ndr.format.smartspim.hasAllChannels(testCase.FixtureDir));
        end

        function testHasAllChannelsFalseForBadInput(testCase)
            testCase.verifyFalse(ndr.format.smartspim.hasAllChannels(tempname));
            testCase.verifyFalse(ndr.format.smartspim.hasAllChannels(42));
        end

        function testHasAllChannelsFalseWhenChannelMissing(testCase)
            delete(fullfile(testCase.FixtureDir, 'All_Channels', '*_ch1.tiff'));
            testCase.verifyFalse(ndr.format.smartspim.hasAllChannels(testCase.FixtureDir));
            testCase.verifyError( ...
                @() ndr.format.smartspim.readAllChannelsInfo(testCase.FixtureDir), ...
                'ndr:format:smartspim:readAllChannelsInfo:MissingChannel');
        end

        function testInfoChannelsByFilterChannelRank(testCase)
            info = ndr.format.smartspim.readAllChannelsInfo(testCase.FixtureDir);
            testCase.verifyEqual(info.channelNames, ...
                {'Ex_561_Em_561F_Ch2', 'Ex_640_Em_640F_Ch3'});
            testCase.verifyEqual([info.channels.chIndex], [0 1]);
            testCase.verifyEqual([info.channels.numSlices], [4 4]);
            testCase.verifyEqual(info.height, 106);
            testCase.verifyEqual(info.width, 13);
            testCase.verifyEqual(info.dtype, 'uint16');
            testCase.verifyEqual(info.voxelSizeUm, [4 4 4]);
            [~, lastName, ext] = fileparts(info.channels(2).slicePaths{end});
            testCase.verifyEqual([lastName ext], '200000_100000_000030_ch1.tiff');
        end

        function testInfoUint16WithExplicitSampleFormat(testCase)
            % libtiff writers (e.g. TeraStitcher) may store SampleFormat = 1,
            % which imfinfo reports as 'Unsigned integer'.
            info = ndr.format.smartspim.readAllChannelsInfo(testCase.FixtureDir);
            writeTiffWithSampleFormat(info.channels(1).slicePaths{1}, ...
                repmat(uint16(40000), 106, 13), Tiff.SampleFormat.UInt);
            info = ndr.format.smartspim.readAllChannelsInfo(testCase.FixtureDir);
            testCase.verifyEqual(info.dtype, 'uint16');
            vol = ndr.format.smartspim.readAllChannelsVolume( ...
                testCase.FixtureDir, 'Ex_561_Em_561F_Ch2', 'ZRange', [1 1]);
            testCase.verifyEqual(vol(1, 1, 1), uint16(40000));
        end

        function testInfoWithoutHeader(testCase)
            info = ndr.format.smartspim.readAllChannelsInfo(testCase.FixtureDir, ...
                'ReadHeader', false);
            testCase.verifyTrue(isnan(info.height));
            testCase.verifyEqual(info.dtype, '');
        end

        function testSlicesSortedNumerically(testCase)
            % z fields of different widths must sort by value, not text:
            % "5" sorts after "000030" as text but between 0 and 10 by value.
            allDir = fullfile(testCase.FixtureDir, 'All_Channels');
            for k = 0:1
                img = repmat(uint16(1000 * (k + 1) + 99), 106, 13);
                imwrite(img, fullfile(allDir, ...
                    sprintf('200000_100000_5_ch%d.tiff', k)), 'tif');
            end
            info = ndr.format.smartspim.readAllChannelsInfo(testCase.FixtureDir);
            testCase.verifyEqual(info.channels(1).numSlices, 5);
            [~, secondName] = fileparts(info.channels(1).slicePaths{2});
            testCase.verifyEqual(secondName, '200000_100000_5_ch0');
        end

        function testSlicesNamedWithoutOrigins(testCase)
            % Some versions of the pipeline name the slices
            % <z*10>_ch<k>.tiff, without the <Y>_<X>_ origins.
            allDir = fullfile(testCase.FixtureDir, 'All_Channels');
            before = ndr.format.smartspim.readAllChannelsInfo(testCase.FixtureDir);
            d = dir(fullfile(allDir, '*_ch*.tiff'));
            for i = 1:numel(d)
                tok = regexp(d(i).name, '^\d+_\d+_(\d+_ch\d+\.tiff)$', 'tokens', 'once');
                movefile(fullfile(allDir, d(i).name), fullfile(allDir, tok{1}));
            end
            testCase.verifyTrue(ndr.format.smartspim.hasAllChannels(testCase.FixtureDir));
            info = ndr.format.smartspim.readAllChannelsInfo(testCase.FixtureDir);
            testCase.verifyEqual(info.channelNames, before.channelNames);
            testCase.verifyEqual([info.channels.numSlices], [before.channels.numSlices]);
            [~, lastName, ext] = fileparts(info.channels(2).slicePaths{end});
            testCase.verifyEqual([lastName ext], '000030_ch1.tiff');
            vol = ndr.format.smartspim.readAllChannelsVolume( ...
                testCase.FixtureDir, 'Ex_640_Em_640F_Ch3');
            testCase.verifyEqual(vol(:, 1, 1).', uint16(2000:2003), ...
                'ch1''s slices, in z order');
        end

        function testTwoFilesForOneSliceAreRefused(testCase)
            % Same channel and z under two names: tiles, not stitched
            % slices, and no single plane to read.
            allDir = fullfile(testCase.FixtureDir, 'All_Channels');
            copyfile(fullfile(allDir, '200000_100000_000000_ch0.tiff'), ...
                fullfile(allDir, '000000_ch0.tiff'));
            testCase.verifyError(@() ndr.format.smartspim.readAllChannelsInfo( ...
                testCase.FixtureDir), 'ndr:format:smartspim:readAllChannelsInfo:DuplicateSlice');
            testCase.verifyFalse(ndr.format.smartspim.hasAllChannels(testCase.FixtureDir));
        end

        function testMipStitchedOverridesRank(testCase)
            % SmartSPIM may assign _ch<k> in a different order; the
            % _MIP_stitched suffix is authoritative.
            for c = {{'Ex_561_Em_561F_Ch2', 1}, {'Ex_640_Em_640F_Ch3', 0}}
                mip = fullfile(testCase.FixtureDir, [c{1}{1} '_MIP_stitched']);
                mkdir(mip);
                imwrite(zeros(2, 2, 'uint16'), fullfile(mip, ...
                    sprintf('200000_100000_000000_ch%d.tiff', c{1}{2})), 'tif');
            end
            info = ndr.format.smartspim.readAllChannelsInfo(testCase.FixtureDir);
            testCase.verifyEqual(info.channelNames, ...
                {'Ex_640_Em_640F_Ch3', 'Ex_561_Em_561F_Ch2'});
            vol = ndr.format.smartspim.readAllChannelsVolume( ...
                testCase.FixtureDir, 'Ex_561_Em_561F_Ch2', 'ZRange', [1 1]);
            testCase.verifyEqual(vol(1, 1, 1), uint16(2000));
        end

        function testSingleChannelWithoutChNumber(testCase)
            % Some SmartSPIM software versions name a single channel's
            % folder Ex_<laser>_Em_<filter> (no _Ch<n>) and its stitched
            % slices Z<z*10>_Ch<k>.tif. Working folders (_MIP, _stitched,
            % _MIDDLE) beside it are not channels.
            root = testCase.FixtureDir;
            allDir = fullfile(root, 'All_Channels');
            rmdir(fullfile(root, 'Ex_640_Em_640F_Ch3'), 's');
            delete(fullfile(allDir, '*_ch1.tiff'));
            movefile(fullfile(root, 'Ex_561_Em_561F_Ch2'), fullfile(root, 'Ex_561_Em_561F'));
            for w = {'_MIP', '_MIP_stitched', '_stitched', '_MIDDLE'}
                mkdir(fullfile(root, ['Ex_561_Em_561F' w{1}]));
            end
            d = dir(fullfile(allDir, '*_ch0.tiff'));
            for i = 1:numel(d)
                tok = regexp(d(i).name, '^\d+_\d+_(\d+)_ch0\.tiff$', 'tokens', 'once');
                movefile(fullfile(allDir, d(i).name), fullfile(allDir, ['Z' tok{1} '_Ch0.tif']));
            end
            testCase.verifyTrue(ndr.format.smartspim.isSmartSPIM(root));
            ch = ndr.format.smartspim.listChannels(root);
            testCase.verifyEqual({ch.name}, {'Ex_561_Em_561F'});
            testCase.verifyEqual(ch.wavelength, 561);
            testCase.verifyEqual(ch.filterName, '561F');
            testCase.verifyEqual(ch.filterChannel, 2, ...
                'from metadata.json''s tiles of its laser and filter');
            testCase.verifyEqual(ch.numTiles, 2, 'tiles of its laser and filter');
            testCase.verifyTrue(ndr.format.smartspim.hasAllChannels(root));
            info = ndr.format.smartspim.readAllChannelsInfo(root);
            testCase.verifyEqual(info.channelNames, {'Ex_561_Em_561F'});
            testCase.verifyEqual(info.channels.chIndex, 0);
            testCase.verifyEqual(info.channels.numSlices, 4);
            vol = ndr.format.smartspim.readAllChannelsVolume(root, 'Ex_561_Em_561F');
            testCase.verifyEqual(vol(:, 1, 1).', uint16(1000:1003), 'in z order');
        end

        function testSeveralChannelsNumberedByMetadata(testCase)
            % SmartSPIM 6.0 names channel folders Ex_<laser>_Em_<filter>
            % (no _Ch<n>); metadata.json's tiles still give each laser and
            % filter its FilterChannel (561F -> 2, 640F -> 3), and the
            % filter-channel rank gives _ch<k> as for numbered folders.
            root = testCase.FixtureDir;
            movefile(fullfile(root, 'Ex_561_Em_561F_Ch2'), fullfile(root, 'Ex_561_Em_561F'));
            movefile(fullfile(root, 'Ex_640_Em_640F_Ch3'), fullfile(root, 'Ex_640_Em_640F'));
            ch = ndr.format.smartspim.listChannels(root);
            testCase.verifyEqual({ch.name}, {'Ex_561_Em_561F', 'Ex_640_Em_640F'});
            testCase.verifyEqual([ch.filterChannel], [2 3]);
            testCase.verifyEqual([ch.numTiles], [2 2]);
            info = ndr.format.smartspim.readAllChannelsInfo(root);
            testCase.verifyEqual(info.channelNames, {'Ex_561_Em_561F', 'Ex_640_Em_640F'});
            vol = ndr.format.smartspim.readAllChannelsVolume(root, 'Ex_640_Em_640F');
            testCase.verifyEqual(vol(:, 1, 1).', uint16(2000:2003), '640 is _ch1');
            % One numbered and one not works the same way.
            movefile(fullfile(root, 'Ex_561_Em_561F'), fullfile(root, 'Ex_561_Em_561F_Ch2'));
            info = ndr.format.smartspim.readAllChannelsInfo(root);
            testCase.verifyEqual(info.channelNames, {'Ex_561_Em_561F_Ch2', 'Ex_640_Em_640F'});
        end

        function testFilterOrderAndMetadataOrderMustAgree(testCase)
            % Unnumbered folders mapped by filter-channel rank: refused when
            % metadata.json lists the channels in the other order, until an
            % acquisition shows which order the stitcher follows.
            root = testCase.FixtureDir;
            movefile(fullfile(root, 'Ex_561_Em_561F_Ch2'), fullfile(root, 'Ex_561_Em_561F'));
            movefile(fullfile(root, 'Ex_640_Em_640F_Ch3'), fullfile(root, 'Ex_640_Em_640F'));
            metaPath = fullfile(root, 'metadata.json');
            meta = jsondecode(fileread(metaPath));
            lasers = arrayfun(@(t) str2double(t.Laser), meta.tiles);
            meta.tiles = [meta.tiles(lasers == 640); meta.tiles(lasers ~= 640)];
            fid = fopen(metaPath, 'w'); fprintf(fid, '%s', jsonencode(meta)); fclose(fid);
            testCase.verifyError(@() ndr.format.smartspim.readAllChannelsInfo(root), ...
                'ndr:format:smartspim:readAllChannelsInfo:ChannelOrderDisagrees');
            testCase.verifyFalse(ndr.format.smartspim.hasAllChannels(root));
            % A direct record settles it.
            writeImsNotes(root, {'Ex_561_Em_561F', 0; 'Ex_640_Em_640F', 1});
            info = ndr.format.smartspim.readAllChannelsInfo(root);
            testCase.verifyEqual(info.channelNames, {'Ex_561_Em_561F', 'Ex_640_Em_640F'});
        end

        function testSeveralUnnumberedChannelsWithoutEvidenceAreRefused(testCase)
            % No _Ch<n>, no metadata.json numbers, no IMS_Notes.txt: which
            % _ch<k> slices are whose would be a guess, so refuse.
            root = testCase.FixtureDir;
            movefile(fullfile(root, 'Ex_561_Em_561F_Ch2'), fullfile(root, 'Ex_561_Em_561F'));
            movefile(fullfile(root, 'Ex_640_Em_640F_Ch3'), fullfile(root, 'Ex_640_Em_640F'));
            delete(fullfile(root, 'metadata.json'));
            testCase.verifyError(@() ndr.format.smartspim.listChannels(root), ...
                'ndr:format:smartspim:listChannels:UnnumberedChannels');
            testCase.verifyError(@() ndr.format.smartspim.readAllChannelsInfo(root), ...
                'ndr:format:smartspim:listChannels:UnnumberedChannels');
            testCase.verifyFalse(ndr.format.smartspim.hasAllChannels(root));
            % IMS_Notes.txt naming only one of them is not enough.
            writeImsNotes(root, {'Ex_561_Em_561F', 0});
            testCase.verifyError(@() ndr.format.smartspim.listChannels(root), ...
                'ndr:format:smartspim:listChannels:UnnumberedChannels');
        end

        function testImsNotesNameEachChannelsSlices(testCase)
            % IMS_Notes.txt is SmartSPIM's own record of which folder is
            % which Ch<k>; it settles unnumbered folders, and outranks the
            % filter-channel rank (here it says the opposite of the rank).
            root = testCase.FixtureDir;
            movefile(fullfile(root, 'Ex_561_Em_561F_Ch2'), fullfile(root, 'Ex_561_Em_561F'));
            movefile(fullfile(root, 'Ex_640_Em_640F_Ch3'), fullfile(root, 'Ex_640_Em_640F'));
            delete(fullfile(root, 'metadata.json'));
            writeImsNotes(root, {'Ex_561_Em_561F', 1; 'Ex_640_Em_640F', 0});
            notes = ndr.format.smartspim.readImsNotes(root);
            testCase.verifyEqual({notes.channelName}, {'Ex_561_Em_561F', 'Ex_640_Em_640F'});
            testCase.verifyEqual([notes.chIndex], [1 0]);
            info = ndr.format.smartspim.readAllChannelsInfo(root);
            testCase.verifyEqual(info.channelNames, {'Ex_640_Em_640F', 'Ex_561_Em_561F'});
            vol = ndr.format.smartspim.readAllChannelsVolume(root, 'Ex_561_Em_561F');
            testCase.verifyEqual(vol(:, 1, 1).', uint16(2000:2003), '561 is _ch1 here');
        end

        function testReadImsNotesWithoutAFile(testCase)
            testCase.verifyEmpty(ndr.format.smartspim.readImsNotes(testCase.FixtureDir));
            testCase.verifyEmpty(ndr.format.smartspim.readImsNotes(''));
        end

        function testInfoErrorsWithoutFolder(testCase)
            rmdir(fullfile(testCase.FixtureDir, 'All_Channels'), 's');
            testCase.verifyError( ...
                @() ndr.format.smartspim.readAllChannelsInfo(testCase.FixtureDir), ...
                'ndr:format:smartspim:readAllChannelsInfo:NoAllChannels');
        end

        function testInfoErrorsWithoutSlices(testCase)
            delete(fullfile(testCase.FixtureDir, 'All_Channels', '*.tiff'));
            testCase.verifyError( ...
                @() ndr.format.smartspim.readAllChannelsInfo(testCase.FixtureDir), ...
                'ndr:format:smartspim:readAllChannelsInfo:NoSlices');
        end

        function testReadVolumeFull(testCase)
            vol = ndr.format.smartspim.readAllChannelsVolume( ...
                testCase.FixtureDir, 'Ex_640_Em_640F_Ch3');
            testCase.verifySize(vol, [4 106 13]);
            testCase.verifyClass(vol, 'uint16');
            testCase.verifyEqual(squeeze(vol(:, 5, 7)).', uint16([2000 2001 2002 2003]));
        end

        function testReadVolumeZRange(testCase)
            vol = ndr.format.smartspim.readAllChannelsVolume( ...
                testCase.FixtureDir, 'Ex_561_Em_561F_Ch2', 'ZRange', [2 3]);
            testCase.verifySize(vol, [2 106 13]);
            testCase.verifyEqual(squeeze(vol(:, 1, 1)).', uint16([1001 1002]));
        end

        function testReadVolumeBadZRange(testCase)
            testCase.verifyError( ...
                @() ndr.format.smartspim.readAllChannelsVolume( ...
                    testCase.FixtureDir, 'Ex_561_Em_561F_Ch2', 'ZRange', [0 2]), ...
                'ndr:format:smartspim:readAllChannelsVolume:BadZRange');
            testCase.verifyError( ...
                @() ndr.format.smartspim.readAllChannelsVolume( ...
                    testCase.FixtureDir, 'Ex_561_Em_561F_Ch2', 'ZRange', [3 5]), ...
                'ndr:format:smartspim:readAllChannelsVolume:BadZRange');
        end

        function testReadVolumeUnknownChannel(testCase)
            testCase.verifyError( ...
                @() ndr.format.smartspim.readAllChannelsVolume( ...
                    testCase.FixtureDir, 'Ex_488_Em_488F_Ch1'), ...
                'ndr:format:smartspim:readAllChannelsVolume:NoSuchChannel');
        end

    end
end

function writeImsNotes(root, rows)
    % IMS_Notes.txt as SmartSPIM writes it: rows are {channel folder, k}.
    lines = cell(1, size(rows, 1));
    for r = 1:size(rows, 1)
        lines{r} = sprintf(['The folder %s_stitched is represented as Ch%d with a ' ...
            'Hex color value of #ff0000'], rows{r, 1}, rows{r, 2});
    end
    fid = fopen(fullfile(root, 'IMS_Notes.txt'), 'w');
    fprintf(fid, '%s\n\n', lines{:});
    fclose(fid);
end

function safeRmdir(d)
    if ~isempty(d) && isfolder(d)
        rmdir(d, 's');
    end
end

function writeTiffWithSampleFormat(path, data, sampleFormat)
    % Write a single-page grayscale TIFF that stores the SampleFormat tag.
    t = Tiff(path, 'w');
    cleanup = onCleanup(@() t.close());
    t.setTag('ImageLength', size(data, 1));
    t.setTag('ImageWidth', size(data, 2));
    t.setTag('Photometric', Tiff.Photometric.MinIsBlack);
    t.setTag('BitsPerSample', 8 * numel(typecast(data(1), 'uint8')));
    t.setTag('SamplesPerPixel', 1);
    t.setTag('SampleFormat', sampleFormat);
    t.setTag('PlanarConfiguration', Tiff.PlanarConfiguration.Chunky);
    t.setTag('Compression', Tiff.Compression.None);
    t.write(data);
end
