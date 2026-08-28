classdef readVld < matlab.unittest.TestCase
    % READVLD - Verify symmetry artifacts for the VH Lab LabView reader.
    %
    % Parameterized over the two artifact sources ('matlabArtifacts',
    % 'pythonArtifacts'), so one test verifies parity in both directions.
    % When the artifact directory for a given SourceType does not exist the
    % test silently skips, so the suite runs on machines that only have one
    % of the two language ports installed.
    %
    % Mirrors tests/symmetry/read_artifacts/reader/test_read_vld.py

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testReadVldArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', SourceType, ...
                'reader', 'readVld', 'testReadVldArtifacts');

            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            vld_file = fullfile(ndr.fun.ndrpath(), 'example_data', 'example.vld');
            testCase.assumeTrue(isfile(vld_file), ...
                'Example VLD file not available; skipping readArtifacts test.');

            reader = ndr.reader.vld();
            epochstreams = {vld_file};
            epoch_select = 1;

            s0 = 1;
            s1 = 100;

            % --- metadata parity ---
            metaFile = fullfile(artifactDir, 'metadata.json');
            if isfile(metaFile)
                fid = fopen(metaFile, 'r');
                expectedMeta = jsondecode(fread(fid, inf, '*char')');
                fclose(fid);

                channels = reader.getchannelsepoch(epochstreams, epoch_select);
                actualNames = {channels.name};
                expectedNames = cellstr(expectedMeta.channel_names(:))';
                testCase.verifyEqual(actualNames, expectedNames, ...
                    ['Channel names mismatch against ' SourceType ' artifacts.']);

                actualTypes = {channels.type};
                expectedTypes = cellstr(expectedMeta.channel_types(:))';
                testCase.verifyEqual(actualTypes, expectedTypes, ...
                    ['Channel types mismatch against ' SourceType ' artifacts.']);

                actualSr = reader.samplerate(epochstreams, epoch_select, 'ai', 1);
                testCase.verifyEqual(actualSr, expectedMeta.samplerate, 'AbsTol', 1e-9, ...
                    ['Sample rate mismatch against ' SourceType ' artifacts.']);

                actualT0T1 = reader.t0_t1(epochstreams, epoch_select);
                testCase.verifyEqual(actualT0T1{1}(:)', expectedMeta.t0_t1(:)', 'AbsTol', 1e-6, ...
                    ['t0_t1 mismatch against ' SourceType ' artifacts.']);

                actualConv = reader.channelLabelingConvention('analog_in');
                testCase.verifyEqual(char(actualConv), char(expectedMeta.labeling_convention), ...
                    ['channelLabelingConvention mismatch against ' SourceType ' artifacts.']);
            else
                disp(['metadata.json not found in ' SourceType ' artifact directory. Skipping metadata check.']);
            end

            % --- data parity ---
            readFile = fullfile(artifactDir, 'readData.json');
            if isfile(readFile)
                fid = fopen(readFile, 'r');
                expectedRead = jsondecode(fread(fid, inf, '*char')');
                fclose(fid);

                ch1 = reader.readchannels_epochsamples('analog_in', 1, epochstreams, epoch_select, s0, s1);
                testCase.verifyEqual(ch1(:)', expectedRead.ai_channel_1_samples_1_100(:)', ...
                    'AbsTol', 1e-9, ...
                    ['Data mismatch for ai channel 1 against ' SourceType ' artifacts.']);

                ch3 = reader.readchannels_epochsamples('analog_in', 3, epochstreams, epoch_select, s0, s1);
                testCase.verifyEqual(ch3(:)', expectedRead.ai_channel_3_samples_1_100(:)', ...
                    'AbsTol', 1e-9, ...
                    ['Data mismatch for ai channel 3 against ' SourceType ' artifacts.']);

                time = reader.readchannels_epochsamples('time', 1, epochstreams, epoch_select, s0, 10);
                testCase.verifyEqual(time(:)', expectedRead.time_samples_1_10(:)', ...
                    'AbsTol', 1e-9, ...
                    ['Time mismatch against ' SourceType ' artifacts.']);
            else
                disp(['readData.json not found in ' SourceType ' artifact directory. Skipping data check.']);
            end
        end
    end
end
