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
