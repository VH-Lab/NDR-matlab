classdef readData < matlab.unittest.TestCase
    % READDATA - Verify symmetry artifacts for NDR reader tests.
    %
    % This test is parameterized over the two potential sources of
    % artifacts ('matlabArtifacts', 'pythonArtifacts'). It loads the
    % JSON dumps produced by the corresponding makeArtifacts suite and
    % confirms that the MATLAB NDR reader returns matching values for
    % the same example data file.
    %
    % When the artifact directory for a given SourceType does not exist,
    % the test silently skips so that the suite can run on machines that
    % only have one of the two language ports installed.

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testReadDataArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', SourceType, ...
                'reader', 'readData', 'testReadDataArtifacts');

            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            rhd_file = fullfile(ndr.fun.ndrpath(), 'example_data', 'example.rhd');
            testCase.assumeTrue(isfile(rhd_file), ...
                'Example RHD file not available; skipping readArtifacts test.');

            reader = ndr.reader.intan_rhd();
            epochstreams = {rhd_file};
            epoch_select = 1;
            channeltype = 'ai';
            channel = 1;

            % --- metadata parity ---
            metaFile = fullfile(artifactDir, 'metadata.json');
            if isfile(metaFile)
                fid = fopen(metaFile, 'r');
                expectedMeta = jsondecode(fread(fid, inf, '*char')');
                fclose(fid);

                actualSr = reader.samplerate(epochstreams, epoch_select, channeltype, channel);
                testCase.verifyEqual(actualSr, expectedMeta.samplerate, 'AbsTol', 1e-9, ...
                    ['Sample rate mismatch against ' SourceType ' artifacts.']);

                actualT0T1 = reader.t0_t1(epochstreams, epoch_select);
                testCase.verifyEqual(actualT0T1{1}(:)', expectedMeta.t0_t1(:)', 'AbsTol', 1e-6, ...
                    ['t0_t1 mismatch against ' SourceType ' artifacts.']);
            else
                disp(['metadata.json not found in ' SourceType ' artifact directory. Skipping metadata check.']);
            end

            % --- raw data parity ---
            readFile = fullfile(artifactDir, 'readData.json');
            if isfile(readFile)
                fid = fopen(readFile, 'r');
                expectedRead = jsondecode(fread(fid, inf, '*char')');
                fclose(fid);

                expectedSamples = expectedRead.ai_channel_1_samples_1_100(:)';
                actualData = reader.readchannels_epochsamples(channeltype, channel, ...
                    epochstreams, epoch_select, 1, 100);

                testCase.verifyEqual(actualData(:)', expectedSamples, 'AbsTol', 1e-9, ...
                    ['Data mismatch for ai channel 1 samples 1-100 against ' SourceType ' artifacts.']);
            else
                disp(['readData.json not found in ' SourceType ' artifact directory. Skipping data check.']);
            end
        end
    end
end
