classdef TestOMEZarrReader < matlab.unittest.TestCase
    % TestOMEZarrReader - frame API for ndr.reader.omezarr against a
    % JSON-only fixture.
    %
    % Pixel reading is filed as issue #130 and is not yet implemented; the
    % reader's readframes method errors clearly until that lands. These
    % tests cover the metadata half of the frame API (resolveepoch,
    % numframes, framesize, dimensionorder, datatype, epochclock, t0_t1,
    % frametimes, getchannelsepoch) plus the epochstream parsing rules
    % from issue #131:
    %
    %   - An epochstream that does not pin a pyramid errors with a
    %     message naming the available pyramids. There is no default
    %     pyramid, ever.
    %   - {zarrPath, pyramidName} pins the pyramid.
    %   - Sidecar files handed along by the file navigator are ignored.
    %
    % The fixture is the same JSON-only dual-pyramid store used by the
    % format-layer tests. No toolbox is required.

    properties
        FixtureDir
    end

    methods (TestMethodSetup)
        function makeFixture(testCase)
            testCase.FixtureDir = ndr.test.format.omezarr.makeExampleFixture();
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
            r = ndr.reader.omezarr();
            n = r.numframes({testCase.FixtureDir, 'mean'}, 1);
            testCase.verifyEqual(n, 256, ...
                'Z size at level 1 must be 256 (fixture builds a 256^3 volume)');
        end

        function testFrameSize(testCase)
            r = ndr.reader.omezarr();
            sz = r.framesize({testCase.FixtureDir, 'mean'}, 1);
            testCase.verifyEqual(sz, [256 256 1 1 256], ...
                'framesize must be [Y X C Z T] with Z=1, T=numframes');
        end

        function testDimensionOrder(testCase)
            r = ndr.reader.omezarr();
            order = r.dimensionorder({testCase.FixtureDir, 'mean'}, 1);
            testCase.verifyEqual(order, 'YXCZT');
        end

        function testDatatype(testCase)
            r = ndr.reader.omezarr();
            dt = r.datatype({testCase.FixtureDir, 'mean'}, 1);
            testCase.verifyEqual(dt, 'uint16', ...
                'fixture dtype "<u2" must map to uint16');
        end

        function testFrameTimesAllNaN(testCase)
            r = ndr.reader.omezarr();
            t = r.frametimes({testCase.FixtureDir, 'mean'}, 1, [1 5 10]);
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

        function testReadframesErrorsUntilFormatLands(testCase)
            % readframes requires ndr.format.omezarr.readArray, which is
            % filed as issue #130. Until that lands, this must error
            % clearly rather than return fake or partial data.
            r = ndr.reader.omezarr();
            if ~isempty(which('ndr.format.omezarr.readArray'))
                % readArray has landed; this test is stale and should
                % be replaced with real pixel-read coverage.
                return;
            end
            testCase.verifyError( ...
                @() r.readframes({testCase.FixtureDir, 'mean'}, 1, 1), ...
                'ndr:reader:omezarr:readArrayNotImplemented');
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
end

function safeRmdir(d)
    if ~isempty(d) && isfolder(d)
        rmdir(d, 's');
    end
end
