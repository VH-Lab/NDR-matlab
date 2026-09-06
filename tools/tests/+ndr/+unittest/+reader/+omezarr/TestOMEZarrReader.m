classdef TestOMEZarrReader < matlab.unittest.TestCase
    % TestOMEZarrReader - frame API for ndr.reader.omezarr against a
    % dual-pyramid fixture with real chunk bytes.
    %
    % Metadata coverage:
    %   resolveepoch (pinned / unpinned / unknown / with-sidecars),
    %   numframes, framesize, dimensionorder, datatype, epochclock,
    %   t0_t1, frametimes, getchannelsepoch.
    %
    % Pixel-read coverage (the ndr.reader.omezarr layer, on top of
    % ndr.format.omezarr.readArray):
    %   * a single-frame read returns bytes that match the ground-truth
    %     slice through the seeded level-0 volume, in the reader's
    %     [Y X C 1 nFrames] frame layout;
    %   * a multi-frame read returns the frames in the requested order;
    %   * the Level option reads from a lower-resolution level;
    %   * mean vs max at level 2 return different pixels (the pyramid
    %     selection actually routes) -- the direct answer to issue #127's
    %     silent-lens concern at the reader boundary.
    %
    % The fixture is built by ndr.test.format.omezarr.makeExampleFixture
    % with WithChunks=true, so real Blosc+Zstd chunks are written and the
    % ground-truth arrays are returned. That path depends on the system
    % `zstd` binary being on PATH (which the readArray path requires
    % anyway).
    %
    % Epochstream rules from issue #131 that these tests pin:
    %   - An epochstream that does not pin a pyramid errors with a
    %     message naming the available pyramids. There is no default
    %     pyramid, ever.
    %   - {zarrPath, pyramidName} pins the pyramid.
    %   - Sidecar files handed along by the file navigator are ignored.

    properties
        FixtureDir
        GroundTruth
    end

    methods (TestMethodSetup)
        function makeFixture(testCase)
            [testCase.FixtureDir, testCase.GroundTruth] = ...
                ndr.test.format.omezarr.makeExampleFixture('', ...
                'WithChunks', true);
            testCase.addTeardown(@() safeRmdir(testCase.FixtureDir));
        end
    end

    methods (Test)

        function testResolveEpochWithPinnedPyramid(testCase)
            r = ndr.reader.omezarr();
            info = r.resolveepoch({testCase.FixtureDir, 'mean'});
            testCase.verifyEqual(info.zarrPath, testCase.FixtureDir);
            testCase.verifyEqual(info.pyramidName, 'mean');
            testCase.verifyEqual(info.axisIndex.c, 1);
            testCase.verifyEqual(info.axisIndex.z, 2);
            testCase.verifyEqual(info.axisIndex.y, 3);
            testCase.verifyEqual(info.axisIndex.x, 4);
        end

        function testUnpinnedPyramidErrors(testCase)
            r = ndr.reader.omezarr();
            testCase.verifyError( ...
                @() r.resolveepoch(testCase.FixtureDir), ...
                'ndr:reader:omezarr:PyramidNotPinned');
            testCase.verifyError( ...
                @() r.resolveepoch({testCase.FixtureDir}), ...
                'ndr:reader:omezarr:PyramidNotPinned');
        end

        function testUnknownPyramidErrors(testCase)
            r = ndr.reader.omezarr();
            testCase.verifyError( ...
                @() r.resolveepoch({testCase.FixtureDir, 'median'}), ...
                'ndr:reader:omezarr:UnknownPyramid');
        end

        function testSidecarsAreIgnored(testCase)
            sidecar = fullfile(testCase.FixtureDir, '..', 'sidecar.json');
            fid = fopen(sidecar, 'w');
            fwrite(fid, '{"note":"acquisition sidecar"}', 'char');
            fclose(fid);
            testCase.addTeardown(@() delete(sidecar));

            r = ndr.reader.omezarr();
            info = r.resolveepoch({{testCase.FixtureDir, 'max'}, sidecar});
            testCase.verifyEqual(info.pyramidName, 'max');
            testCase.verifyEqual(info.zarrPath, testCase.FixtureDir);
        end

        function testNumFrames(testCase)
            % Fixture level-0 shape is [c z y x] = [1 8 8 10] with
            % WithChunks=true, so numframes (Z) must be 8.
            r = ndr.reader.omezarr();
            n = r.numframes({testCase.FixtureDir, 'mean'}, 1);
            testCase.verifyEqual(n, 8);
        end

        function testFrameSize(testCase)
            r = ndr.reader.omezarr();
            sz = r.framesize({testCase.FixtureDir, 'mean'}, 1);
            testCase.verifyEqual(sz, [8 10 1 1 8], ...
                'framesize must be [Y X C Z T] from level-0 shape [1 8 8 10]');
        end

        function testDimensionOrder(testCase)
            r = ndr.reader.omezarr();
            order = r.dimensionorder({testCase.FixtureDir, 'mean'}, 1);
            testCase.verifyEqual(order, 'YXCZT');
        end

        function testDatatype(testCase)
            r = ndr.reader.omezarr();
            dt = r.datatype({testCase.FixtureDir, 'mean'}, 1);
            testCase.verifyEqual(dt, 'uint16');
        end

        function testFrameTimesAllNaN(testCase)
            r = ndr.reader.omezarr();
            t = r.frametimes({testCase.FixtureDir, 'mean'}, 1, [1 5 8]);
            testCase.verifyEqual(numel(t), 3);
            testCase.verifyTrue(all(isnan(t)));
        end

        function testEpochClockIsNoTime(testCase)
            r = ndr.reader.omezarr();
            ec = r.epochclock({testCase.FixtureDir, 'mean'}, 1);
            testCase.verifyClass(ec, 'cell');
            testCase.verifyClass(ec{1}, 'ndr.time.clocktype');
        end

        function testT0T1IsNaN(testCase)
            r = ndr.reader.omezarr();
            t0t1 = r.t0_t1({testCase.FixtureDir, 'mean'}, 1);
            testCase.verifyEqual(t0t1, {[NaN NaN]});
        end

        function testGetChannelsEpoch(testCase)
            r = ndr.reader.omezarr();
            ch = r.getchannelsepoch({testCase.FixtureDir, 'mean'}, 1);
            testCase.verifyEqual(numel(ch), 1);
            testCase.verifyEqual(ch(1).name, 'image1');
            testCase.verifyEqual(ch(1).type, 'image');
        end

        function testReadFramesSingleFrameMatchesGroundTruth(testCase)
            % A single-frame read at level 1 must equal the corresponding
            % z-slice of the seeded level-0 volume, in [Y X C 1 1] shape.
            r = ndr.reader.omezarr();
            frameIdx = 3;
            frames = r.readframes({testCase.FixtureDir, 'mean'}, 1, frameIdx);
            expected = testCase.zSlice(testCase.GroundTruth.level0, frameIdx);
            testCase.verifySize(frames, [8 10 1 1 1]);
            testCase.verifyClass(frames, 'uint16');
            testCase.verifyEqual(frames(:,:,:,1,1), expected);
        end

        function testReadFramesMultipleFramesInOrder(testCase)
            % A multi-frame read must place frames along dim 5 in the
            % requested order.
            r = ndr.reader.omezarr();
            frameInds = [1 4 7];
            frames = r.readframes({testCase.FixtureDir, 'mean'}, 1, frameInds);
            testCase.verifySize(frames, [8 10 1 1 3]);
            for k = 1:numel(frameInds)
                expected = testCase.zSlice( ...
                    testCase.GroundTruth.level0, frameInds(k));
                testCase.verifyEqual(frames(:,:,:,1,k), expected, ...
                    sprintf('frame at index %d must match ground truth', ...
                    frameInds(k)));
            end
        end

        function testReadFramesLevelOptionSelectsLowerResolution(testCase)
            % 'Level', 2 in the reader is pyramid.levels(2), which points
            % at 'mean/1' -- the 2x downsample (fixture GroundTruth field
            % meanLevel1, shape [1 4 4 5]). Level 1 is the shared root.
            r = ndr.reader.omezarr();
            frameIdx = 1;
            frames = r.readframes({testCase.FixtureDir, 'mean'}, 1, ...
                frameIdx, 'Level', 2);
            expected = testCase.zSlice( ...
                testCase.GroundTruth.meanLevel1, frameIdx);
            % 2x-downsample shape [1 4 4 5] -> frame [Y X C] = [4 5 1]
            testCase.verifySize(frames, [4 5 1 1 1]);
            testCase.verifyEqual(frames(:,:,:,1,1), expected);
        end

        function testMeanAndMaxDifferAtLevel2(testCase)
            % The whole point of pinning a pyramid: mean and max return
            % different pixels at the same coordinates. Compare at
            % pyramid.levels(2) = 'mean/1' vs 'max/1' (the 2x
            % downsamples). If a reader silently substituted one for the
            % other, this would pass by accident and hide a bug -- so
            % verify the fixture generates non-equal downsamples and then
            % verify the reader routes to the requested one.
            gt = testCase.GroundTruth;
            testCase.assumeFalse( ...
                isequal(gt.meanLevel1, gt.maxLevel1), ...
                'fixture must generate mean != max at the 2x downsample');

            r = ndr.reader.omezarr();
            meanFrame = r.readframes({testCase.FixtureDir, 'mean'}, 1, 1, ...
                'Level', 2);
            maxFrame  = r.readframes({testCase.FixtureDir, 'max'},  1, 1, ...
                'Level', 2);
            testCase.verifyEqual(meanFrame(:,:,:,1,1), ...
                testCase.zSlice(gt.meanLevel1, 1));
            testCase.verifyEqual(maxFrame(:,:,:,1,1), ...
                testCase.zSlice(gt.maxLevel1, 1));
            testCase.verifyFalse( ...
                isequal(meanFrame, maxFrame), ...
                'mean and max reads must not return the same pixels');
        end

        function testReadFramesAllFramesDefault(testCase)
            % An empty frameind reads all frames.
            r = ndr.reader.omezarr();
            frames = r.readframes({testCase.FixtureDir, 'mean'}, 1, []);
            testCase.verifySize(frames, [8 10 1 1 8]);
        end

        function testZarrClassMapping(testCase)
            testCase.verifyEqual( ...
                ndr.reader.omezarr.zarrClass('<u2'), 'uint16');
            testCase.verifyEqual( ...
                ndr.reader.omezarr.zarrClass('>i4'), 'int32');
            testCase.verifyEqual( ...
                ndr.reader.omezarr.zarrClass('|u1'), 'uint8');
            testCase.verifyEqual( ...
                ndr.reader.omezarr.zarrClass('f8'), 'double');
            testCase.verifyError( ...
                @() ndr.reader.omezarr.zarrClass('<c16'), ...
                'ndr:reader:omezarr:UnsupportedDtype');
        end

    end

    methods (Access = private)

        function slice = zSlice(~, vol, zIndex)
            % Extract one z-plane from a ground-truth (c, z, y, x) volume
            % and reshape it to the reader's [Y X C] per-frame layout.
            % The fixture stores level-0 as [1 Z Y X] uint16, so the
            % slice is (y, x) with a single channel.
            planeCZYX = vol(:, zIndex, :, :);
            % permute (c, z, y, x) -> (y, x, c, z), then drop z (=1)
            planeYXCZ = permute(planeCZYX, [3 4 1 2]);
            slice = reshape(planeYXCZ, size(planeYXCZ, 1), ...
                size(planeYXCZ, 2), size(planeYXCZ, 3));
        end

    end
end

function safeRmdir(d)
    if ~isempty(d) && isfolder(d)
        rmdir(d, 's');
    end
end
