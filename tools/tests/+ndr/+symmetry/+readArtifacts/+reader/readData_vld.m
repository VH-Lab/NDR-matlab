classdef readData_vld < matlab.unittest.TestCase
    % READDATA_VLD - Read back and verify symmetry artifacts for the NDR vld
    % reader (mirrors readData.m for the intan reader).
    %
    % Parameterized over the two artifact sources. matlabArtifacts are always
    % produced in-job by the makeArtifacts suite, so a MISSING matlabArtifacts
    % directory is a real failure (verifyFail), not a silent pass. The
    % pythonArtifacts leg is a vacuous pass (return, NOT assumeFail so it does
    % not register as Incomplete) until an actual NDR-python job is wired in.

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testReadDataVldArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', SourceType, ...
                'reader', 'readData', 'testReadDataVldArtifacts');

            if ~isfolder(artifactDir)
                if strcmp(SourceType, 'matlabArtifacts')
                    testCase.verifyFail(['Expected matlabArtifacts directory was ' ...
                        'not produced by the makeArtifacts suite: ' artifactDir]);
                    return;
                else
                    % No Python leg yet: pass vacuously (must NOT be Incomplete).
                    disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                    return;
                end
            end

            vld_file = fullfile(ndr.fun.ndrpath(), 'example_data', 'vld_example.vld');
            testCase.assumeTrue(isfile(vld_file), ...
                'Example VLD file not available; skipping readArtifacts test.');

            reader = ndr.reader.vld();
            epochstreams = {vld_file};
            epoch_select = 1;
            channeltype = 'ai';
            channel = 1;

            metaFile = fullfile(artifactDir, 'metadata.json');
            testCase.verifyTrue(isfile(metaFile), ...
                ['metadata.json missing in ' SourceType ' artifacts.']);
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
            end

            readFile = fullfile(artifactDir, 'readData.json');
            testCase.verifyTrue(isfile(readFile), ...
                ['readData.json missing in ' SourceType ' artifacts.']);
            if isfile(readFile)
                fid = fopen(readFile, 'r');
                expectedRead = jsondecode(fread(fid, inf, '*char')');
                fclose(fid);
                expectedSamples = expectedRead.ai_channel_1_samples_1_100(:)';
                actualData = reader.readchannels_epochsamples(channeltype, channel, ...
                    epochstreams, epoch_select, 1, 100);
                testCase.verifyEqual(actualData(:)', expectedSamples, 'AbsTol', 1e-9, ...
                    ['Data mismatch for ai channel 1 samples 1-100 against ' SourceType ' artifacts.']);
            end
        end
    end
end
