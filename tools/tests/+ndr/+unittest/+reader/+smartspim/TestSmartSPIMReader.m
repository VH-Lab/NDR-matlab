classdef TestSmartSPIMReader < matlab.unittest.TestCase
    % TestSmartSPIMReader - frame API for ndr.reader.smartspim against a
    % synthetic 2-channel, 2-tile fixture with real TIFF slices.
    %
    % Metadata coverage:
    %   resolveepoch (pinned / unpinned channel / unpinned tile /
    %   with-sidecars), numframes, framesize, dimensionorder, datatype,
    %   epochclock, t0_t1, frametimes, getchannelsepoch.
    %
    % Pixel-read coverage:
    %   * a single-frame read returns the expected uint16 slice from the
    %     synthetic fixture (pixel_value = 100 * channelIndex + z);
    %   * a multi-frame read returns frames in the requested order along
    %     dim 5 with layout [Y X C Z T] = [8 10 1 1 nFrames];
    %   * a different channel epoch returns different pixels -- the
    %     pinning actually routes;
    %   * out-of-range frame indices error.
    %
    % Epochstream rules that these tests pin:
    %   - An epochstream that does not pin a channel errors with a
    %     message naming the available channels.
    %   - An epochstream that pins a channel but not a tile errors with
    %     a message naming the available tiles.
    %   - {rootDir, channelName, tileId} pins the tile.
    %   - Sidecar files handed along by the file navigator are ignored.

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

        function testResolveEpochWithPinnedTile(testCase)
            r = ndr.reader.smartspim();
            info = r.resolveepoch({testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000'});
            testCase.verifyEqual(info.rootDir, testCase.FixtureDir);
            testCase.verifyEqual(info.channelName, 'Ex_561_Em_561F_Ch2');
            testCase.verifyEqual(info.tileId, '100000/100000_200000');
            testCase.verifyEqual(info.tile.numSlices, 4);
            testCase.verifyEqual(info.tile.height, 8);
            testCase.verifyEqual(info.tile.width, 10);
        end

        function testUnpinnedChannelErrors(testCase)
            r = ndr.reader.smartspim();
            testCase.verifyError( ...
                @() r.resolveepoch(testCase.FixtureDir), ...
                'ndr:reader:smartspim:ChannelNotPinned');
            testCase.verifyError( ...
                @() r.resolveepoch({testCase.FixtureDir}), ...
                'ndr:reader:smartspim:ChannelNotPinned');
        end

        function testUnpinnedTileErrors(testCase)
            r = ndr.reader.smartspim();
            testCase.verifyError( ...
                @() r.resolveepoch({testCase.FixtureDir, 'Ex_561_Em_561F_Ch2'}), ...
                'ndr:reader:smartspim:TileNotPinned');
        end

        function testMissingRootErrors(testCase)
            r = ndr.reader.smartspim();
            testCase.verifyError( ...
                @() r.resolveepoch({tempname, 'Ex_561_Em_561F_Ch2', 'x/y'}), ...
                'ndr:reader:smartspim:NotADirectory');
        end

        function testSidecarsAreIgnored(testCase)
            sidecar = fullfile(testCase.FixtureDir, '..', 'sidecar.json');
            fid = fopen(sidecar, 'w');
            fwrite(fid, '{"note":"acquisition sidecar"}', 'char');
            fclose(fid);
            testCase.addTeardown(@() delete(sidecar));

            r = ndr.reader.smartspim();
            info = r.resolveepoch({ ...
                {testCase.FixtureDir, 'Ex_640_Em_640F_Ch3', '100000/100000_300000'}, ...
                sidecar});
            testCase.verifyEqual(info.channelName, 'Ex_640_Em_640F_Ch3');
            testCase.verifyEqual(info.tileId, '100000/100000_300000');
        end

        function testNumFrames(testCase)
            r = ndr.reader.smartspim();
            n = r.numframes({testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000'}, 1);
            testCase.verifyEqual(n, 4);
        end

        function testFrameSize(testCase)
            r = ndr.reader.smartspim();
            sz = r.framesize({testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000'}, 1);
            testCase.verifyEqual(sz, [8 10 1 1 4]);
        end

        function testDimensionOrder(testCase)
            r = ndr.reader.smartspim();
            order = r.dimensionorder({testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000'}, 1);
            testCase.verifyEqual(order, 'YXCZT');
        end

        function testDatatype(testCase)
            r = ndr.reader.smartspim();
            dt = r.datatype({testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000'}, 1);
            testCase.verifyEqual(dt, 'uint16');
        end

        function testFrameTimesAllNaN(testCase)
            r = ndr.reader.smartspim();
            t = r.frametimes({testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000'}, 1, [1 3]);
            testCase.verifyEqual(numel(t), 2);
            testCase.verifyTrue(all(isnan(t)));
        end

        function testEpochClockIsNoTime(testCase)
            r = ndr.reader.smartspim();
            ec = r.epochclock({testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000'}, 1);
            testCase.verifyClass(ec, 'cell');
            testCase.verifyClass(ec{1}, 'ndr.time.clocktype');
        end

        function testT0T1IsNaN(testCase)
            r = ndr.reader.smartspim();
            t0t1 = r.t0_t1({testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000'}, 1);
            testCase.verifyEqual(t0t1, {[NaN NaN]});
        end

        function testGetChannelsEpoch(testCase)
            r = ndr.reader.smartspim();
            ch = r.getchannelsepoch({testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000'}, 1);
            testCase.verifyEqual(numel(ch), 1);
            testCase.verifyEqual(ch(1).name, 'image1');
            testCase.verifyEqual(ch(1).type, 'image');
        end

        function testReadFramesSingleFrameMatchesFixture(testCase)
            r = ndr.reader.smartspim();
            % Fixture rule: pixel_value(channelIndex=1, z=0) = 100
            frames = r.readframes({testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000'}, 1, 1);
            testCase.verifySize(frames, [8 10 1 1 1]);
            testCase.verifyClass(frames, 'uint16');
            testCase.verifyEqual(frames(1, 1, 1, 1, 1), uint16(100));
        end

        function testReadFramesMultipleFramesInOrder(testCase)
            r = ndr.reader.smartspim();
            frameInds = [1 3 4];
            frames = r.readframes({testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000'}, 1, frameInds);
            testCase.verifySize(frames, [8 10 1 1 3]);
            % Fixture: pixel = 100 * 1 + (frameIdx - 1)
            expected = uint16([100 102 103]);
            actual = uint16([frames(1,1,1,1,1), ...
                             frames(1,1,1,1,2), ...
                             frames(1,1,1,1,3)]);
            testCase.verifyEqual(actual, expected);
        end

        function testDifferentChannelDifferentPixels(testCase)
            % Pins actually route: Ex_640 has channelIndex=2 in the fixture,
            % so pixel(z=0) = 200 not 100.
            r = ndr.reader.smartspim();
            frames = r.readframes({testCase.FixtureDir, ...
                'Ex_640_Em_640F_Ch3', '100000/100000_200000'}, 1, 1);
            testCase.verifyEqual(frames(1, 1, 1, 1, 1), uint16(200));
        end

        function testReadFramesDefaultReadsAll(testCase)
            r = ndr.reader.smartspim();
            frames = r.readframes({testCase.FixtureDir, ...
                'Ex_561_Em_561F_Ch2', '100000/100000_200000'}, 1, []);
            testCase.verifySize(frames, [8 10 1 1 4]);
        end

        function testReadFramesOutOfRangeErrors(testCase)
            r = ndr.reader.smartspim();
            testCase.verifyError( ...
                @() r.readframes({testCase.FixtureDir, ...
                    'Ex_561_Em_561F_Ch2', '100000/100000_200000'}, 1, [1 99]), ...
                'ndr:reader:smartspim:FrameOutOfRange');
        end

    end
end

function safeRmdir(d)
    if ~isempty(d) && isfolder(d)
        rmdir(d, 's');
    end
end
