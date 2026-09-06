classdef readOmeZarr < matlab.unittest.TestCase
    % READOMEZARR - verify ndr.format.omezarr.readArray output against
    % the SHA-256 checksums the other language port recorded in its
    % symmetry artifacts.
    %
    % Parameterized over both source types; each SourceType is skipped
    % (silently) when its artifact directory is absent, so the suite
    % runs on machines with only one language port installed. See
    % +symmetry/+readArtifacts/INSTRUCTIONS.md.
    %
    % The fixture is the SAME on-disk store both ports point their
    % readers at (it lives inside the artifact directory as
    % example.zarr). What differs between ports is not the bytes on
    % disk but the reader that decodes them. A per-region SHA-256
    % mismatch means the MATLAB reader and the other-port reader
    % disagree on the decoded bytes, which for a lossless codec is a
    % correctness bug in one of them.

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testReadOmeZarrArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', ...
                SourceType, 'format', 'readOmeZarr', ...
                'testReadOmeZarrArtifacts');
            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ...
                      ' does not exist. Skipping.']);
                return;
            end

            checksumsFile = fullfile(artifactDir, 'checksums.json');
            testCase.assumeTrue(isfile(checksumsFile), ...
                sprintf('checksums.json not present in %s.', SourceType));

            metaFile = fullfile(artifactDir, 'metadata.json');
            metadata = readJson(metaFile);

            fixtureDir = fullfile(artifactDir, metadata.fixtureName);
            testCase.assumeTrue(isfolder(fixtureDir), ...
                sprintf('Fixture %s missing under %s.', ...
                        metadata.fixtureName, artifactDir));

            % zstd is a runtime dependency for reading the fixture on
            % this side; assumeTrue rather than an error so the suite
            % skips gracefully on a machine that lacks it (the makeSide
            % has the same skip).
            if ispc
                [s, ~] = system('where zstd');
            else
                [s, ~] = system('command -v zstd');
            end
            testCase.assumeEqual(s, 0, ...
                'zstd CLI not on PATH; cannot read OME-Zarr artifacts.');

            checksums = readJson(checksumsFile);
            entries = checksums.regions;
            if isstruct(entries)
                entries = num2cell(entries(:)');
            end

            for i = 1:numel(entries)
                e = entries{i};
                if isempty(e.region)
                    got = ndr.format.omezarr.readArray( ...
                        fixtureDir, e.pyramid, e.level);
                else
                    got = ndr.format.omezarr.readArray( ...
                        fixtureDir, e.pyramid, e.level, 'Region', e.region);
                end
                actual = sha256Hex(typecast(got(:), 'uint8'));
                testCase.verifyEqual(actual, lower(e.sha256), ...
                    sprintf(['Region "%s" (pyramid %s level %d) ' ...
                             'SHA-256 mismatch against %s. This means ' ...
                             'the MATLAB reader and the other-port ' ...
                             'reader disagree on the decoded bytes; ' ...
                             'that is a lossless codec, so one of ' ...
                             'them is wrong.'], ...
                        e.name, e.pyramid, e.level, SourceType));
            end
        end
    end
end

function s = readJson(path)
    fid = fopen(path, 'r');
    if fid < 0
        error('ndr:symmetry:readArtifacts:format:readOmeZarr:OpenFailed', ...
            'Could not open %s for reading.', path);
    end
    cleanup = onCleanup(@() fclose(fid));
    raw = fread(fid, inf, '*char')';
    s = jsondecode(raw);
end

function h = sha256Hex(bytes)
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(bytes(:));
    digest = typecast(md.digest(), 'uint8');
    h = lower(reshape(dec2hex(digest, 2)', 1, []));
end
