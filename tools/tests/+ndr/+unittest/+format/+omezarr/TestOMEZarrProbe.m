classdef TestOMEZarrProbe < matlab.unittest.TestCase
    % TestOMEZarrProbe - probe() cheap metadata summary
    %
    % Exercises the wrapper over isOMEZarr + listPyramids that ingest
    % / GUI confirmation screens use to answer "should we accept this?".
    % The fixture is the same programmatic one TestOMEZarr uses; probe
    % reads no chunk bytes so no toolbox is required.

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
        function testOkOnFixture(testCase)
            info = ndr.format.omezarr.probe(testCase.FixtureDir);
            testCase.verifyTrue(info.ok);
        end

        function testNotOkOnMissingDir(testCase)
            info = ndr.format.omezarr.probe(tempname);
            testCase.verifyFalse(info.ok);
            testCase.verifyEqual(info.nPyramids, 0);
            testCase.verifyEmpty(info.pyramidNames);
        end

        function testNotOkOnEmptyDirectory(testCase)
            emptyDir = tempname;
            mkdir(emptyDir);
            testCase.addTeardown(@() rmdir(emptyDir, 's'));
            info = ndr.format.omezarr.probe(emptyDir);
            testCase.verifyFalse(info.ok);
        end

        function testPyramidCountAndNames(testCase)
            % The fixture ships mean + max pyramids; probe reports both.
            info = ndr.format.omezarr.probe(testCase.FixtureDir);
            testCase.verifyEqual(info.nPyramids, 2);
            testCase.verifyTrue(any(strcmp(info.pyramidNames, 'mean')));
            testCase.verifyTrue(any(strcmp(info.pyramidNames, 'max')));
        end

        function testFirstPyramidMetadata(testCase)
            info = ndr.format.omezarr.probe(testCase.FixtureDir);
            testCase.verifyEqual(char(info.axesOrder), 'czyx');
            testCase.verifyEqual(numel(info.axesUnits), 4);
            testCase.verifyEqual(numel(info.level0Shape), 4);
            testCase.verifyEqual(numel(info.level0Chunks), 4);
            testCase.verifyEqual(numel(info.level0Scale), 4);
            testCase.verifyNotEmpty(info.dtype);
        end

        function testNLevelsPerPyramid(testCase)
            info = ndr.format.omezarr.probe(testCase.FixtureDir);
            testCase.verifyEqual(numel(info.nLevelsPerPyramid), 2);
            testCase.verifyTrue(all(info.nLevelsPerPyramid >= 1));
        end
    end
end

function safeRmdir(d)
    if ~isempty(d) && isfolder(d)
        rmdir(d, 's');
    end
end
