function test(varargin)
% ndr.test.format.omezarr.test - unit tests for +ndr/+format/+omezarr
%
%   ndr.test.format.omezarr.TEST()
%
%   Exercises the discovery/metadata layer against a programmatically
%   built fixture that mirrors the lab dual-pyramid layout (see
%   ferret-lightsheet/formats/OurUsualZarrFormat.md). No chunk bytes
%   are read, so no toolbox dependency is required.
%
%   Prints one line per test and errors if any fails.

    fixtureDir = ndr.test.format.omezarr.makeExampleFixture();
    cleanup = onCleanup(@() safeRmdir(fixtureDir));  %#ok<NASGU>

    testIsOMEZarr(fixtureDir);
    testReadAttrs(fixtureDir);
    testListPyramids(fixtureDir);
    testResolveArrayPath(fixtureDir);
    testSharedLevelZero(fixtureDir);
    testUnknownPyramidErrors(fixtureDir);
    testLevelOutOfRangeErrors(fixtureDir);

    disp('ndr.test.format.omezarr.test: all tests passed.');
end

function testIsOMEZarr(fixtureDir)
    assertTrue(ndr.format.omezarr.isOMEZarr(fixtureDir), ...
        'isOMEZarr should be true for a valid fixture');
    assertFalse(ndr.format.omezarr.isOMEZarr(tempname), ...
        'isOMEZarr should be false for a nonexistent path');
    emptyDir = tempname;
    mkdir(emptyDir);
    cleanup = onCleanup(@() rmdir(emptyDir, 's'));  %#ok<NASGU>
    assertFalse(ndr.format.omezarr.isOMEZarr(emptyDir), ...
        'isOMEZarr should be false for a directory without .zattrs');
    disp('  ok: isOMEZarr');
end

function testReadAttrs(fixtureDir)
    attrs = ndr.format.omezarr.readAttrs(fixtureDir);
    assertTrue(isstruct(attrs), 'readAttrs must return a struct');
    assertTrue(isfield(attrs, 'multiscales'), ...
        'readAttrs must carry the multiscales field');
    disp('  ok: readAttrs');
end

function testListPyramids(fixtureDir)
    pyramids = ndr.format.omezarr.listPyramids(fixtureDir);
    assertEqual(numel(pyramids), 2, ...
        'fixture must expose exactly two pyramids');

    names = {pyramids.name};
    assertTrue(any(strcmp(names, 'mean')), 'expected a "mean" pyramid');
    assertTrue(any(strcmp(names, 'max')),  'expected a "max" pyramid');

    for i = 1:numel(pyramids)
        assertEqual(numel(pyramids(i).levels), 3, ...
            sprintf('pyramid %s must have three levels', pyramids(i).name));
        for k = 1:numel(pyramids(i).levels)
            L = pyramids(i).levels(k);
            assertTrue(~isempty(L.shape),  'level.shape must be populated');
            assertTrue(~isempty(L.chunks), 'level.chunks must be populated');
            assertTrue(~isempty(L.dtype),  'level.dtype must be populated');
            assertEqual(numel(L.scale), 4, ...
                'level.scale must have 4 entries for (c,z,y,x)');
        end
    end

    axes = pyramids(1).axes;
    assertEqual(numel(axes), 4, 'axes must have 4 entries for (c,z,y,x)');
    assertEqual(axes(1).name, 'c', 'axis 1 must be c');
    assertEqual(axes(2).name, 'z', 'axis 2 must be z');

    disp('  ok: listPyramids');
end

function testResolveArrayPath(fixtureDir)
    p = ndr.format.omezarr.resolveArrayPath(fixtureDir, 'mean', 2);
    assertTrue(isfolder(p), ...
        'resolveArrayPath must return an existing directory');
    assertTrue(isfile(fullfile(p, '.zarray')), ...
        'resolved directory must contain a .zarray');
    disp('  ok: resolveArrayPath');
end

function testSharedLevelZero(fixtureDir)
    pMean = ndr.format.omezarr.resolveArrayPath(fixtureDir, 'mean', 1);
    pMax  = ndr.format.omezarr.resolveArrayPath(fixtureDir, 'max',  1);
    assertEqual(pMean, pMax, ...
        'the two pyramids must resolve to the same on-disk array at level 1 (shared level 0)');
    disp('  ok: sharedLevelZero');
end

function testUnknownPyramidErrors(fixtureDir)
    caught = false;
    try
        ndr.format.omezarr.resolveArrayPath(fixtureDir, 'median', 1);
    catch ME
        caught = strcmp(ME.identifier, ...
            'ndr:format:omezarr:resolveArrayPath:UnknownPyramid');
    end
    assertTrue(caught, ...
        'resolveArrayPath must error on an unknown pyramid name');
    disp('  ok: unknownPyramidErrors');
end

function testLevelOutOfRangeErrors(fixtureDir)
    caught = false;
    try
        ndr.format.omezarr.resolveArrayPath(fixtureDir, 'mean', 99);
    catch ME
        caught = strcmp(ME.identifier, ...
            'ndr:format:omezarr:resolveArrayPath:LevelOutOfRange');
    end
    assertTrue(caught, ...
        'resolveArrayPath must error when level exceeds the pyramid');
    disp('  ok: levelOutOfRangeErrors');
end

function safeRmdir(d)
    if ~isempty(d) && isfolder(d)
        rmdir(d, 's');
    end
end

function assertTrue(cond, msg)
    if ~cond
        error('ndr:test:format:omezarr:assertion', 'assertTrue failed: %s', msg);
    end
end

function assertFalse(cond, msg)
    if cond
        error('ndr:test:format:omezarr:assertion', 'assertFalse failed: %s', msg);
    end
end

function assertEqual(actual, expected, msg)
    if ~isequal(actual, expected)
        error('ndr:test:format:omezarr:assertion', ...
            'assertEqual failed: %s (expected %s, got %s)', msg, ...
            toStr(expected), toStr(actual));
    end
end

function s = toStr(v)
    if ischar(v)
        s = v;
    elseif isnumeric(v) || islogical(v)
        s = mat2str(v);
    else
        s = class(v);
    end
end
