classdef TestOMEZarr < matlab.unittest.TestCase
    % TestOMEZarr - discovery/metadata layer for +ndr/+format/+omezarr
    %
    % The fixture is built programmatically by
    % ndr.test.format.omezarr.makeExampleFixture, which writes only
    % .zattrs, .zgroup, and .zarray files -- no chunk bytes. That is
    % enough for isOMEZarr, readAttrs, listPyramids, and
    % resolveArrayPath, none of which touch pixels. Pixel reading is
    % filed as a follow-up so the toolbox vs. minimum-MATLAB tradeoff
    % from issue #127 can be settled once.
    %
    % The layout mirrors ferret-lightsheet/formats/OurUsualZarrFormat.md:
    % two multiscales entries (mean, max), both with datasets(1).path =
    % '0' so their highest-resolution level is the shared root array.
    % That is where the silent-failure risk lives -- a reader that picks
    % multiscales[0] gets mean and never mentions max -- so the shared
    % level 0 and the by-name selection are exercised together.
    %
    % No toolbox is required to run these tests.

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
        function testIsOMEZarrTrueForFixture(testCase)
            testCase.verifyTrue( ...
                ndr.format.omezarr.isOMEZarr(testCase.FixtureDir));
        end

        function testIsOMEZarrFalseForNonexistent(testCase)
            testCase.verifyFalse( ...
                ndr.format.omezarr.isOMEZarr(tempname));
        end

        function testIsOMEZarrFalseForEmptyDirectory(testCase)
            emptyDir = tempname;
            mkdir(emptyDir);
            testCase.addTeardown(@() rmdir(emptyDir, 's'));
            testCase.verifyFalse(ndr.format.omezarr.isOMEZarr(emptyDir));
        end

        function testReadAttrsReturnsStruct(testCase)
            attrs = ndr.format.omezarr.readAttrs(testCase.FixtureDir);
            testCase.verifyTrue(isstruct(attrs));
            testCase.verifyTrue(isfield(attrs, 'multiscales'));
        end

        function testReadAttrsErrorsOnMissingZattrs(testCase)
            d = tempname;
            mkdir(d);
            testCase.addTeardown(@() rmdir(d, 's'));
            testCase.verifyError(@() ndr.format.omezarr.readAttrs(d), ...
                'ndr:format:omezarr:readAttrs:MissingZattrs');
        end

        function testListPyramidsHasBothNames(testCase)
            pyramids = ndr.format.omezarr.listPyramids(testCase.FixtureDir);
            testCase.verifyEqual(numel(pyramids), 2);
            names = {pyramids.name};
            testCase.verifyTrue(any(strcmp(names, 'mean')));
            testCase.verifyTrue(any(strcmp(names, 'max')));
        end

        function testListPyramidsLevelsHaveMetadata(testCase)
            pyramids = ndr.format.omezarr.listPyramids(testCase.FixtureDir);
            for i = 1:numel(pyramids)
                lvls = pyramids(i).levels;
                testCase.verifyEqual(numel(lvls), 3, ...
                    sprintf('pyramid %s must expose 3 levels', ...
                    pyramids(i).name));
                for k = 1:numel(lvls)
                    testCase.verifyNotEmpty(lvls(k).shape);
                    testCase.verifyNotEmpty(lvls(k).chunks);
                    testCase.verifyNotEmpty(lvls(k).dtype);
                    testCase.verifyEqual(numel(lvls(k).scale), 4);
                end
            end
        end

        function testListPyramidsAxesCZYX(testCase)
            pyramids = ndr.format.omezarr.listPyramids(testCase.FixtureDir);
            axes = pyramids(1).axes;
            testCase.verifyEqual(numel(axes), 4);
            testCase.verifyEqual(axes(1).name, 'c');
            testCase.verifyEqual(axes(2).name, 'z');
            testCase.verifyEqual(axes(3).name, 'y');
            testCase.verifyEqual(axes(4).name, 'x');
        end

        function testResolveArrayPathReturnsExistingDir(testCase)
            p = ndr.format.omezarr.resolveArrayPath( ...
                testCase.FixtureDir, 'mean', 2);
            testCase.verifyTrue(isfolder(p));
            testCase.verifyTrue(isfile(fullfile(p, '.zarray')));
        end

        function testResolveSharedLevelZero(testCase)
            % Both pyramids' level 1 must resolve to the same on-disk
            % array; this is the whole point of the shared-foundation
            % layout and the failure mode this reader exists to prevent.
            pMean = ndr.format.omezarr.resolveArrayPath( ...
                testCase.FixtureDir, 'mean', 1);
            pMax = ndr.format.omezarr.resolveArrayPath( ...
                testCase.FixtureDir, 'max', 1);
            testCase.verifyEqual(pMean, pMax);
        end

        function testResolveDistinctAtHigherLevels(testCase)
            pMean = ndr.format.omezarr.resolveArrayPath( ...
                testCase.FixtureDir, 'mean', 2);
            pMax = ndr.format.omezarr.resolveArrayPath( ...
                testCase.FixtureDir, 'max', 2);
            testCase.verifyNotEqual(pMean, pMax);
        end

        function testResolveUnknownPyramidErrors(testCase)
            testCase.verifyError( ...
                @() ndr.format.omezarr.resolveArrayPath( ...
                    testCase.FixtureDir, 'median', 1), ...
                'ndr:format:omezarr:resolveArrayPath:UnknownPyramid');
        end

        function testResolveLevelOutOfRangeErrors(testCase)
            testCase.verifyError( ...
                @() ndr.format.omezarr.resolveArrayPath( ...
                    testCase.FixtureDir, 'mean', 99), ...
                'ndr:format:omezarr:resolveArrayPath:LevelOutOfRange');
        end

        function testResolveBadLevelErrors(testCase)
            testCase.verifyError( ...
                @() ndr.format.omezarr.resolveArrayPath( ...
                    testCase.FixtureDir, 'mean', 0), ...
                'ndr:format:omezarr:resolveArrayPath:BadLevel');
            testCase.verifyError( ...
                @() ndr.format.omezarr.resolveArrayPath( ...
                    testCase.FixtureDir, 'mean', 1.5), ...
                'ndr:format:omezarr:resolveArrayPath:BadLevel');
        end
    end
end

function safeRmdir(d)
    if ~isempty(d) && isfolder(d)
        rmdir(d, 's');
    end
end
