classdef readTiffstack < matlab.unittest.TestCase
    % READTIFFSTACK - Verify symmetry artifacts for the tiffstack reader.
    %
    % Parameterized over the two artifact sources ('matlabArtifacts',
    % 'pythonArtifacts'), so one test verifies parity in both directions.
    % Skips when the artifact directory for a given SourceType is absent.
    %
    % Mirrors tests/symmetry/read_artifacts/reader/test_read_images.py

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testReadTiffstackArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', SourceType, ...
                'reader', 'readTiffstack', 'testReadTiffstackArtifacts');

            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            movie_file = fullfile(ndr.fun.ndrpath(), 'example_data', 'example_movie.tif');
            testCase.assumeTrue(isfile(movie_file), ...
                'Example TIFF movie not available; skipping readArtifacts test.');

            reader = ndr.reader.tiffstack();
            epochstreams = {movie_file};
            epoch_select = 1;

            % --- metadata parity ---
            metaFile = fullfile(artifactDir, 'metadata.json');
            if isfile(metaFile)
                fid = fopen(metaFile, 'r');
                expectedMeta = jsondecode(fread(fid, inf, '*char')');
                fclose(fid);

                testCase.verifyEqual(double(reader.numframes(epochstreams, epoch_select)), ...
                    double(expectedMeta.numframes), ...
                    ['numframes mismatch against ' SourceType ' artifacts.']);

                testCase.verifyEqual(double(reader.framesize(epochstreams, epoch_select)), ...
                    double(expectedMeta.framesize(:)'), ...
                    ['framesize mismatch against ' SourceType ' artifacts.']);

                testCase.verifyEqual(char(reader.dimensionorder(epochstreams, epoch_select)), ...
                    char(expectedMeta.dimensionorder), ...
                    ['dimensionorder mismatch against ' SourceType ' artifacts.']);

                % Strict string parity: both ports report the MATLAB class name.
                testCase.verifyEqual(char(reader.datatype(epochstreams, epoch_select)), ...
                    char(expectedMeta.datatype), ...
                    ['datatype mismatch against ' SourceType ' artifacts.']);

                testCase.verifyEqual(logical(reader.hasframetimes(epochstreams)), ...
                    logical(expectedMeta.hasframetimes), ...
                    ['hasframetimes mismatch against ' SourceType ' artifacts.']);

                ft = reader.frametimes(epochstreams, epoch_select);
                testCase.verifyEqual(ft(:)', expectedMeta.frametimes(:)', 'AbsTol', 1e-9, ...
                    ['frametimes mismatch against ' SourceType ' artifacts.']);

                t0t1 = reader.t0_t1(epochstreams, epoch_select);
                testCase.verifyEqual(t0t1{1}(:)', expectedMeta.t0_t1(:)', 'AbsTol', 1e-9, ...
                    ['t0_t1 mismatch against ' SourceType ' artifacts.']);
            else
                disp(['metadata.json not found in ' SourceType ' artifact directory. Skipping metadata check.']);
            end

            % --- frame parity ---
            readFile = fullfile(artifactDir, 'readFrames.json');
            if isfile(readFile)
                fid = fopen(readFile, 'r');
                expectedRead = jsondecode(fread(fid, inf, '*char')');
                fclose(fid);

                frames = reader.readframes(epochstreams, epoch_select, [1 5]);

                testCase.verifyEqual(double(frames(:,:,1,1,1)), double(expectedRead.frame_1), ...
                    ['frame 1 mismatch against ' SourceType ' artifacts.']);
                testCase.verifyEqual(double(frames(:,:,1,1,2)), double(expectedRead.frame_5), ...
                    ['frame 5 mismatch against ' SourceType ' artifacts.']);
            else
                disp(['readFrames.json not found in ' SourceType ' artifact directory. Skipping frame check.']);
            end
        end
    end
end
