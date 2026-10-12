classdef TestSmartSPIMReaderAllChannels < matlab.unittest.TestCase
    % TestSmartSPIMReaderAllChannels - ndr.reader.smartspim on stitched data
    %
    % Uses ndr.test.format.smartspim.makeExampleFixture('AllChannels', true):
    % the usual 2-channel, 2-tile fixture plus an All_Channels folder of
    % 106x13 uint16 slices with pixel = 1000 * (k + 1) + z, where
    % Ex_561_Em_561F_Ch2 -> ch0 and Ex_640_Em_640F_Ch3 -> ch1.
    %
    % Epochstream rules that these tests pin:
    %   - {rootDir} reads the stitched volume with every channel on the
    %     C axis, ordered by the All_Channels _ch<k> index.
    %   - {rootDir, channelName} reads one channel of the stitched volume.
    %   - {rootDir, channelName, tileId} still reads the destriped tile.
    %   - Without a usable All_Channels folder, {rootDir} and
    %     {rootDir, channelName} keep erroring with ChannelNotPinned /
    %     TileNotPinned (covered for the no-All_Channels fixture in
    %     TestSmartSPIMReader).

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

        function testResolveRootIsAllChannels(testCase)
            r = ndr.reader.smartspim();
            info = r.resolveepoch({testCase.FixtureDir});
            testCase.verifyEqual(info.source, 'allChannels');
            testCase.verifyEqual(info.channelName, '');
            testCase.verifyEqual(info.tileId, '');
            testCase.verifyEqual(info.channelNames, ...
                {'Ex_561_Em_561F_Ch2', 'Ex_640_Em_640F_Ch3'});
            testCase.verifyEqual(info.numSlices, 4);
            testCase.verifyEqual(info.allChannels.voxelSizeUm, [4 4 4]);
            % A bare path behaves the same as {rootDir}
            info2 = r.resolveepoch(testCase.FixtureDir);
            testCase.verifyEqual(info2.source, 'allChannels');
        end

        function testResolveChannelIsStitched(testCase)
            r = ndr.reader.smartspim();
            info = r.resolveepoch({testCase.FixtureDir, 'Ex_640_Em_640F_Ch3'});
            testCase.verifyEqual(info.source, 'allChannels');
            testCase.verifyEqual(info.channelNames, {'Ex_640_Em_640F_Ch3'});
            testCase.verifyEmpty(info.tile);
        end

        function testResolveTileStillReadsTile(testCase)
            r = ndr.reader.smartspim();
            info = r.resolveepoch({testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000'});
            testCase.verifyEqual(info.source, 'tile');
            testCase.verifyEqual(info.tile.height, 8);
            testCase.verifyEmpty(info.allChannels);
        end

        function testUnknownChannelErrors(testCase)
            r = ndr.reader.smartspim();
            testCase.verifyError( ...
                @() r.resolveepoch({testCase.FixtureDir, 'Ex_488_Em_488F_Ch1'}), ...
                'ndr:reader:smartspim:NoSuchChannel');
        end

        function testSliceCountMismatchErrorsForRoot(testCase)
            delete(fullfile(testCase.FixtureDir, 'All_Channels', ...
                '200000_100000_000030_ch1.tiff'));
            r = ndr.reader.smartspim();
            testCase.verifyError(@() r.resolveepoch({testCase.FixtureDir}), ...
                'ndr:reader:smartspim:SliceCountMismatch');
            % One channel at a time still works
            testCase.verifyEqual(r.numframes( ...
                {testCase.FixtureDir, 'Ex_640_Em_640F_Ch3'}, 1), 3);
        end

        function testFallbackWhenChannelIncomplete(testCase)
            % A channel without _ch<k> slices makes All_Channels unusable;
            % the reader falls back to the per-tile layout.
            delete(fullfile(testCase.FixtureDir, 'All_Channels', '*_ch1.tiff'));
            r = ndr.reader.smartspim();
            testCase.verifyError(@() r.resolveepoch({testCase.FixtureDir}), ...
                'ndr:reader:smartspim:ChannelNotPinned');
            testCase.verifyError( ...
                @() r.resolveepoch({testCase.FixtureDir, 'Ex_561_Em_561F_Ch2'}), ...
                'ndr:reader:smartspim:TileNotPinned');
        end

        function testFrameSizeAndType(testCase)
            r = ndr.reader.smartspim();
            testCase.verifyEqual(r.framesize({testCase.FixtureDir}, 1), [106 13 2 1 4]);
            testCase.verifyEqual(r.framesize( ...
                {testCase.FixtureDir, 'Ex_561_Em_561F_Ch2'}, 1), [106 13 1 1 4]);
            testCase.verifyEqual(r.numframes({testCase.FixtureDir}, 1), 4);
            testCase.verifyEqual(r.datatype({testCase.FixtureDir}, 1), 'uint16');
            testCase.verifyEqual(r.dimensionorder({testCase.FixtureDir}, 1), 'YXCZT');
            testCase.verifyEqual(numel(r.frametimes({testCase.FixtureDir}, 1)), 4);
        end

        function testReadFramesAllChannels(testCase)
            r = ndr.reader.smartspim();
            frames = r.readframes({testCase.FixtureDir}, 1, [1 2 4]);
            testCase.verifySize(frames, [106 13 2 1 3]);
            testCase.verifyClass(frames, 'uint16');
            testCase.verifyEqual(squeeze(frames(1, 1, 1, 1, :)).', uint16([1000 1001 1003]));
            testCase.verifyEqual(squeeze(frames(9, 4, 2, 1, :)).', uint16([2000 2001 2003]));
        end

        function testReadFramesUnorderedIndices(testCase)
            r = ndr.reader.smartspim();
            frames = r.readframes({testCase.FixtureDir, 'Ex_640_Em_640F_Ch3'}, ...
                1, [4 2 3 3]);
            testCase.verifySize(frames, [106 13 1 1 4]);
            testCase.verifyEqual(squeeze(frames(1, 1, 1, 1, :)).', ...
                uint16([2003 2001 2002 2002]));
        end

        function testReadFramesSelectC(testCase)
            r = ndr.reader.smartspim();
            frames = r.readframes({testCase.FixtureDir}, 1, 2, 'SelectC', 2);
            testCase.verifySize(frames, [106 13 1 1 1]);
            testCase.verifyEqual(frames(1, 1, 1, 1, 1), uint16(2001));
        end

        function testReadFramesDefaultReadsAll(testCase)
            r = ndr.reader.smartspim();
            frames = r.readframes({testCase.FixtureDir}, 1, []);
            testCase.verifySize(frames, [106 13 2 1 4]);
        end

        function testReadFramesOutOfRangeErrors(testCase)
            r = ndr.reader.smartspim();
            testCase.verifyError( ...
                @() r.readframes({testCase.FixtureDir}, 1, [1 5]), ...
                'ndr:reader:smartspim:FrameOutOfRange');
        end

        function testTileReadUnaffected(testCase)
            r = ndr.reader.smartspim();
            frames = r.readframes({testCase.FixtureDir, ...
                'Ex_640_Em_640F_Ch3', '100000/100000_200000'}, 1, 1);
            testCase.verifySize(frames, [8 10 1 1 1]);
            testCase.verifyEqual(frames(1, 1, 1, 1, 1), uint16(200));
        end

    end
end

function safeRmdir(d)
    if ~isempty(d) && isfolder(d)
        rmdir(d, 's');
    end
end
