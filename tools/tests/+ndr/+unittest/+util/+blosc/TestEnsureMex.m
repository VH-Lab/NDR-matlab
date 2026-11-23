classdef TestEnsureMex < matlab.unittest.TestCase
    % TestEnsureMex - ndr.util.blosc.ensureMex must not be fooled by the path.
    %
    % Regression tests for two bugs:
    %   1. ensureMex returned its persistent cached struct (available=true)
    %      without re-checking the path, so after something removed the
    %      install folder from the path every later call still said
    %      available and blosc.encode resolved to whatever else was there.
    %   2. Availability was judged by exist('blosc.encode','file'), which
    %      is true for ANY +blosc package, including a source checkout of
    %      blosc-matlab with no compiled MEX in +blosc/private.
    %
    % The checkMexResolution tests need neither network nor a real MEX.
    % Tests that need a working MEX assume-skip when ensureMex cannot
    % provide one on this platform (no prebuilt, or no network).
    %
    % Each test saves the MATLAB path and current folder and restores them
    % at teardown; stray +blosc copies live in temporary folders.

    properties
        TempRoot (1,:) char = ''
    end

    methods (TestMethodSetup)
        function setupTempAndPath(testCase)
            tempFixture = testCase.applyFixture( ...
                matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.TempRoot = tempFixture.Folder;
            originalPath = path();
            testCase.addTeardown(@path, originalPath);
        end
    end

    methods (Test)
        function testStrayWithoutMexIsNotUsable(testCase)
            strayRoot = testCase.makeStray('strayNoMex', false);
            addpath(strayRoot);
            rehash;

            result = ndr.util.blosc.checkMexResolution();
            testCase.verifyFalse(result.ok, ...
                'A +blosc copy without private/blosc_mex must not count.');
            testCase.verifyEqual(result.folder, ...
                fileparts(which('blosc.encode')));
            testCase.verifyTrue(contains(result.folder, 'strayNoMex'), ...
                sprintf('Expected the stray folder, got %s', result.folder));
            testCase.verifyTrue(contains(result.reason, result.folder), ...
                'The reason must name the shadowing folder.');
        end

        function testStrayWithMexFileIsUsable(testCase)
            % Only the presence of private/blosc_mex.<mexext> next to
            % each wrapper is checked (the MEX is not loaded), so a copy
            % with a placeholder MEX file passes.
            strayRoot = testCase.makeStray('strayWithMex', true);
            addpath(strayRoot);
            rehash;

            result = ndr.util.blosc.checkMexResolution();
            testCase.verifyTrue(result.ok, result.reason);
            testCase.verifyTrue(contains(result.folder, 'strayWithMex'));
            testCase.verifyEmpty(result.reason);
        end

        function testNeverAvailableWhileStrayResolves(testCase)
            % Stray copy in the current folder: the current folder beats
            % the path, so not even addpath-to-top can rescue it. Whatever
            % ensureMex manages to install, it must not claim available.
            strayRoot = testCase.makeStray('strayInCwd', false);
            testCase.applyFixture( ...
                matlab.unittest.fixtures.CurrentFolderFixture(strayRoot));
            rehash;

            info = ndr.util.blosc.ensureMex();
            testCase.verifyFalse(info.available, ...
                'ensureMex reported available although blosc.encode resolves to a copy without MEX.');
            testCase.verifyNotEmpty(info.reason);
            resolution = ndr.util.blosc.checkMexResolution();
            testCase.verifyFalse(resolution.ok);
            if ~isempty(info.mex)
                % A real install exists but is shadowed: the reason
                % must name the shadowing folder.
                testCase.verifyTrue(contains(info.reason, 'strayInCwd'), ...
                    info.reason);
            end
        end

        function testStrayAheadOnPathIsOvertakenByInstall(testCase)
            info0 = ndr.util.blosc.ensureMex();
            testCase.assumeTrue(info0.available, ...
                sprintf('No blosc-matlab MEX on this platform: %s', info0.reason));

            strayRoot = testCase.makeStray('strayOnPath', false);
            addpath(strayRoot); % now ahead of the install
            rehash;
            before = ndr.util.blosc.checkMexResolution();
            testCase.verifyFalse(before.ok, ...
                'Precondition: the stray copy should shadow the install.');

            info = ndr.util.blosc.ensureMex();
            testCase.verifyTrue(info.available, info.reason);
            after = ndr.util.blosc.checkMexResolution();
            testCase.verifyTrue(after.ok, after.reason);
            testCase.verifyFalse(contains(after.folder, 'strayOnPath'), ...
                'The install should have been put back in front of the stray copy.');
        end

        function testStrayInCurrentFolderReportsUnavailable(testCase)
            info0 = ndr.util.blosc.ensureMex();
            testCase.assumeTrue(info0.available, ...
                sprintf('No blosc-matlab MEX on this platform: %s', info0.reason));

            strayRoot = testCase.makeStray('strayCwdCached', false);
            testCase.applyFixture( ...
                matlab.unittest.fixtures.CurrentFolderFixture(strayRoot));
            rehash;

            info = ndr.util.blosc.ensureMex();
            testCase.verifyFalse(info.available, ...
                'The stale cached struct must not be returned.');
            testCase.verifyTrue(contains(info.reason, 'strayCwdCached'), ...
                info.reason);
            % The info fields are unchanged.
            testCase.verifyEqual(sort(fieldnames(info)), ...
                sort({'available'; 'version'; 'path'; 'mex'; 'reason'}));
        end

        function testInstallRemovedFromPathIsRestored(testCase)
            info0 = ndr.util.blosc.ensureMex();
            testCase.assumeTrue(info0.available, ...
                sprintf('No blosc-matlab MEX on this platform: %s', info0.reason));

            % Simulate a path reset after the successful (cached) call.
            rmpath(info0.path);
            testCase.verifyFalse(startsWith(which('blosc.encode'), info0.path), ...
                'Precondition: the install should no longer resolve.');

            info = ndr.util.blosc.ensureMex();
            testCase.verifyTrue(info.available, info.reason);
            resolution = ndr.util.blosc.checkMexResolution();
            testCase.verifyTrue(resolution.ok, resolution.reason);
            testCase.verifyTrue(startsWith(which('blosc.encode'), info0.path), ...
                sprintf('blosc.encode resolves to %s, not the install at %s', ...
                    which('blosc.encode'), info0.path));
        end
    end

    methods (Access = private)
        function strayRoot = makeStray(testCase, name, withMex)
            % Create <TempRoot>/<name>/+blosc with the wrapper functions
            % NDR calls and, if WITHMEX, a placeholder private MEX file.
            strayRoot = fullfile(testCase.TempRoot, name);
            pkgDir = fullfile(strayRoot, '+blosc');
            privDir = fullfile(pkgDir, 'private');
            mkdir(privDir);
            wrappers = {'encode', 'encodeChunk', 'decode'};
            for i = 1:numel(wrappers)
                fid = fopen(fullfile(pkgDir, [wrappers{i} '.m']), 'w');
                fprintf(fid, ['function varargout = %s(varargin)\n' ...
                    'error(''ndr:test:strayBlosc'', ''stray blosc copy'');\n' ...
                    'end\n'], wrappers{i});
                fclose(fid);
            end
            if withMex
                fid = fopen(fullfile(privDir, ['blosc_mex.' mexext]), 'w');
                fclose(fid);
            end
        end
    end
end
