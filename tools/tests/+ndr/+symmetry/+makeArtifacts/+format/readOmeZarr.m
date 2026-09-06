classdef readOmeZarr < matlab.unittest.TestCase
    % READOMEZARR - generate cross-language symmetry artifacts for
    % ndr.format.omezarr.readArray.
    %
    % Zarr is a lossless container, so if MATLAB and Python decompress
    % the same chunk to different bytes, one of them is wrong. This test
    % harness makes that comparison automatable in both directions:
    %
    %   makeArtifacts (MATLAB)  -> writes a small OME-Zarr fixture into
    %                              matlabArtifacts/, then records
    %                              per-region SHA-256 checksums of the
    %                              MATLAB reader's output.
    %
    %   readArtifacts (Python)  -> reads the fixture from matlabArtifacts/
    %                              with its own reader, checks the same
    %                              SHA-256s. Divergence fails CI.
    %
    %   makeArtifacts (Python)  -> writes a fixture using zarr-python's
    %                              Blosc+Zstd encoder into pythonArtifacts/
    %                              with its own checksums.
    %
    %   readArtifacts (MATLAB)  -> reads pythonArtifacts/ with the MATLAB
    %                              reader, checks the checksums.
    %
    % A shared example.zarr in the repo would work too but the issue's
    % explicit direction is to keep binary out of the tree; per the
    % established +makeArtifacts / +readArtifacts contract the artifacts
    % live under tempdir(). See +symmetry/+makeArtifacts/INSTRUCTIONS.md.
    %
    % This class requires the `zstd` CLI to build the fixture; the test
    % skips (assumeTrue) when it is not on PATH.

    methods (Test)
        function testReadOmeZarrArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', ...
                'matlabArtifacts', 'format', 'readOmeZarr', ...
                'testReadOmeZarrArtifacts');
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            % `zstd` is a runtime dependency of both the writer and the
            % reader; skip loudly rather than skip silently.
            if ispc
                [s, ~] = system('where zstd');
            else
                [s, ~] = system('command -v zstd');
            end
            testCase.assumeEqual(s, 0, ...
                'zstd CLI not on PATH; cannot build OME-Zarr artifacts.');

            % Build the fixture WITH real chunks directly into the
            % artifact directory. That is the shared bytes on disk that
            % both language ports read.
            [fixtureDir, gt] = ...
                ndr.test.format.omezarr.makeExampleFixture(artifactDir, ...
                    'WithChunks', true);

            % Metadata: shape, chunk shape, dtype, seed for the
            % downstream fixture-rebuild path if a port needs it.
            metadata = struct( ...
                'fixtureName',      'example.zarr', ...
                'level0Shape',      gt.shape0, ...
                'level0ChunkShape', gt.chunkShape0, ...
                'dtype',            gt.dtype, ...
                'seed',             20260906);
            writeJson(fullfile(artifactDir, 'metadata.json'), metadata);

            % Deterministic set of regions, chosen the same way as
            % TestOMEZarrReadArray: whole, inside-one-chunk, straddle,
            % edge, inside-edge. Each becomes one entry with the
            % pyramid, level, region, and the SHA-256 of the readback
            % bytes.
            regions = struct( ...
                'name',    {}, ...
                'pyramid', {}, ...
                'level',   {}, ...
                'region',  {}, ...
                'sha256',  {});
            regions = appendRegion(testCase, regions, fixtureDir, ...
                'whole_mean_1',     'mean', 1, []);
            regions = appendRegion(testCase, regions, fixtureDir, ...
                'whole_max_1',      'max',  1, []);
            regions = appendRegion(testCase, regions, fixtureDir, ...
                'whole_mean_2',     'mean', 2, []);
            regions = appendRegion(testCase, regions, fixtureDir, ...
                'whole_max_2',      'max',  2, []);
            regions = appendRegion(testCase, regions, fixtureDir, ...
                'inside_one_chunk', 'mean', 1, [1 1 1 1; 1 2 3 3]);
            regions = appendRegion(testCase, regions, fixtureDir, ...
                'straddle',         'mean', 1, [1 3 3 3; 1 6 6 6]);
            regions = appendRegion(testCase, regions, fixtureDir, ...
                'reach_edge_x',     'mean', 1, [1 1 1 7; 1 8 8 10]);
            regions = appendRegion(testCase, regions, fixtureDir, ...
                'inside_edge_x',    'mean', 1, [1 1 1 9; 1 4 4 10]);

            writeJson(fullfile(artifactDir, 'checksums.json'), ...
                struct('regions', {num2cell(regions(:)')}));

            testCase.verifyTrue(isfile(fullfile(artifactDir, 'checksums.json')));
            testCase.verifyTrue(isfolder(fixtureDir));
        end
    end
end

function regions = appendRegion(testCase, regions, fixtureDir, name, pyramid, level, region)
    if isempty(region)
        got = ndr.format.omezarr.readArray(fixtureDir, pyramid, level);
        regionCell = [];
    else
        got = ndr.format.omezarr.readArray(fixtureDir, pyramid, level, ...
            'Region', region);
        regionCell = region;
    end
    entry = struct( ...
        'name',    name, ...
        'pyramid', pyramid, ...
        'level',   level, ...
        'region',  regionCell, ...
        'sha256',  sha256Hex(typecast(got(:), 'uint8')));
    regions(end+1) = entry; %#ok<AGROW>
    testCase.assertTrue(ischar(entry.sha256) && numel(entry.sha256) == 64);
end

function h = sha256Hex(bytes)
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(bytes(:));
    digest = typecast(md.digest(), 'uint8');
    h = lower(reshape(dec2hex(digest, 2)', 1, []));
end

function writeJson(path, s)
    txt = jsonencode(s, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
    fid = fopen(path, 'w');
    if fid < 0
        error('ndr:symmetry:makeArtifacts:format:readOmeZarr:OpenFailed', ...
            'Could not open %s for writing.', path);
    end
    cleanup = onCleanup(@() fclose(fid));
    fwrite(fid, txt, 'char');
end
