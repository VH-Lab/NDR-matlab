classdef TestOMEZarrReadArray < matlab.unittest.TestCase
    % TestOMEZarrReadArray - round-trip test of ndr.format.omezarr.readArray
    % against a Blosc+Zstd-compressed fixture built at fixture-time by
    % ndr.test.format.omezarr.makeExampleFixture(_, 'WithChunks', true).
    %
    % The whole-repo policy against committing binary fixtures is why the
    % fixture is built rather than checked in, and why the writer is
    % implemented independently of the reader in makeExampleFixture: a
    % bug that both share (e.g. a wrong axis order or shuffle
    % convention) would round-trip fine but disagree with any other
    % OME-Zarr consumer. The cross-language check that catches those
    % (Python-produced artifacts read by MATLAB) is filed under
    % tools/tests/+ndr/+symmetry/+readArtifacts/+format/readOmeZarr.m.
    %
    % The fixture picks chunk sizes that make each spatial axis a NON-
    % integer multiple of the chunk size, so the last chunk along each
    % axis is an edge chunk (uncompressed to full chunk_shape and padded
    % with fill_value beyond the array). The tests read regions that:
    %   - cover the whole array
    %   - fit inside one chunk
    %   - straddle a chunk boundary
    %   - reach into the edge chunk on the x axis
    %   - live entirely inside the edge chunk on the x axis
    % All five have to match the ground-truth volume byte for byte.
    %
    % These tests skip cleanly (with a message) when `zstd` is not on
    % PATH -- both the writer and the reader depend on it, and there is
    % no other way to build the fixture in-repo without shipping binary
    % chunks.

    properties
        FixtureDir
        GroundTruth
    end

    methods (TestClassSetup)
        function requireZstd(testCase)
            if ispc
                [s, ~] = system('where zstd');
            else
                [s, ~] = system('command -v zstd');
            end
            testCase.assumeEqual(s, 0, ...
                ['These tests need the `zstd` CLI on PATH. Install it ' ...
                 '(apt/brew/homepage) or skip them.']);
        end
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
        function testWholeLevel0Roundtrip(testCase)
            got = ndr.format.omezarr.readArray( ...
                testCase.FixtureDir, 'mean', 1);
            testCase.verifyClass(got, 'uint16');
            testCase.verifyEqual(size(got, 1:4), ...
                testCase.GroundTruth.shape0);
            testCase.verifyEqual(got, testCase.GroundTruth.level0, ...
                'Whole-array read must equal the volume the fixture wrote.');
        end

        function testSharedLevel0MatchesBothPyramids(testCase)
            gotMean = ndr.format.omezarr.readArray( ...
                testCase.FixtureDir, 'mean', 1);
            gotMax = ndr.format.omezarr.readArray( ...
                testCase.FixtureDir, 'max', 1);
            testCase.verifyEqual(gotMean, gotMax, ...
                ['Level 1 is the shared root array; reading via ' ...
                 'either pyramid name must give the same bytes.']);
        end

        function testInsideOneChunk(testCase)
            % Region entirely within chunk (0,0,0,0) of level 0
            region = [1 1 1 1; 1 2 3 3];
            got = ndr.format.omezarr.readArray( ...
                testCase.FixtureDir, 'mean', 1, 'Region', region);
            expected = testCase.GroundTruth.level0(:, 1:2, 1:3, 1:3);
            testCase.verifyEqual(got, expected);
        end

        function testStraddleChunkBoundary(testCase)
            % Level-0 chunks are [1 4 4 4], so this region crosses
            % boundaries on z, y, and x at once.
            region = [1 3 3 3; 1 6 6 6];
            got = ndr.format.omezarr.readArray( ...
                testCase.FixtureDir, 'mean', 1, 'Region', region);
            expected = testCase.GroundTruth.level0(:, 3:6, 3:6, 3:6);
            testCase.verifyEqual(got, expected);
        end

        function testTouchesEdgeChunkX(testCase)
            % x has shape 10 with chunk 4, so chunks 0,1,2 cover 1..4,
            % 5..8, 9..10. Reading 7..10 spans chunk 1 (7..8) and the
            % edge chunk 2 (9..10).
            region = [1 1 1 7; 1 8 8 10];
            got = ndr.format.omezarr.readArray( ...
                testCase.FixtureDir, 'mean', 1, 'Region', region);
            expected = testCase.GroundTruth.level0(:, :, :, 7:10);
            testCase.verifyEqual(got, expected);
        end

        function testWhollyInsideEdgeChunk(testCase)
            % Region entirely inside the x-edge chunk (positions 9..10).
            region = [1 1 1 9; 1 4 4 10];
            got = ndr.format.omezarr.readArray( ...
                testCase.FixtureDir, 'mean', 1, 'Region', region);
            expected = testCase.GroundTruth.level0(:, 1:4, 1:4, 9:10);
            testCase.verifyEqual(got, expected);
        end

        function testMeanAndMaxPyramidsDisagreeAboveLevel1(testCase)
            % Level 2 downsamples with different reducers; the fixture
            % builds them independently, so reader outputs must differ
            % and match the pre-computed downsamples.
            gotMean = ndr.format.omezarr.readArray( ...
                testCase.FixtureDir, 'mean', 2);
            gotMax = ndr.format.omezarr.readArray( ...
                testCase.FixtureDir, 'max', 2);
            testCase.verifyEqual(gotMean, testCase.GroundTruth.meanLevel1);
            testCase.verifyEqual(gotMax,  testCase.GroundTruth.maxLevel1);
            testCase.verifyFalse(isequal(gotMean, gotMax), ...
                'mean and max downsamples of random data must differ.');
        end

        function testOutputTypeCastsToRequestedClass(testCase)
            got = ndr.format.omezarr.readArray( ...
                testCase.FixtureDir, 'mean', 1, 'OutputType', 'single');
            testCase.verifyClass(got, 'single');
            testCase.verifyEqual(got, single(testCase.GroundTruth.level0));
        end

        function testBadRegionShapeErrors(testCase)
            testCase.verifyError(@() ndr.format.omezarr.readArray( ...
                testCase.FixtureDir, 'mean', 1, ...
                'Region', [1 1 1; 2 2 2]), ...
                'ndr:format:omezarr:readArray:BadRegion');
        end

        function testRegionOutOfBoundsErrors(testCase)
            % x has shape 10; stop=99 is beyond it.
            testCase.verifyError(@() ndr.format.omezarr.readArray( ...
                testCase.FixtureDir, 'mean', 1, ...
                'Region', [1 1 1 1; 1 8 8 99]), ...
                'ndr:format:omezarr:readArray:RegionOutOfBounds');
        end

        function testUnknownPyramidStillErrors(testCase)
            % readArray delegates the unknown-pyramid check to
            % resolveArrayPath; the same error identifier must reach the
            % caller.
            testCase.verifyError(@() ndr.format.omezarr.readArray( ...
                testCase.FixtureDir, 'median', 1), ...
                'ndr:format:omezarr:resolveArrayPath:UnknownPyramid');
        end
    end
end

function safeRmdir(d)
    if ~isempty(d) && isfolder(d)
        rmdir(d, 's');
    end
end
