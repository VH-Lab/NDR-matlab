classdef readData_prairieview < matlab.unittest.TestCase
    % READDATA_PRAIRIEVIEW - Read back and verify symmetry artifacts for the NDR
    % prairieview reader (mirrors readData.m for the intan reader).
    %
    % matlabArtifacts are always produced in-job by the makeArtifacts suite, so
    % a MISSING matlabArtifacts directory is a real failure (verifyFail). The
    % pythonArtifacts leg passes vacuously (return, not Incomplete) until a real
    % NDR-python job is wired in.

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    methods (Test)
        function testReadDataPrairieviewArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', SourceType, ...
                'reader', 'readData', 'testReadDataPrairieviewArtifacts');

            if ~isfolder(artifactDir)
                if strcmp(SourceType, 'matlabArtifacts')
                    testCase.verifyFail(['Expected matlabArtifacts directory was ' ...
                        'not produced by the makeArtifacts suite: ' artifactDir]);
                    return;
                else
                    disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                    return;
                end
            end

            pv_dir = fullfile(ndr.fun.ndrpath(), 'example_data', 'prairieview_example');
            testCase.assumeTrue(isfolder(pv_dir), ...
                'Example Prairie View directory not available; skipping readArtifacts test.');

            reader = ndr.reader.prairieview();
            epochstreams = {pv_dir};
            epoch_select = 1;

            metaFile = fullfile(artifactDir, 'metadata.json');
            testCase.verifyTrue(isfile(metaFile), ...
                ['metadata.json missing in ' SourceType ' artifacts.']);
            if isfile(metaFile)
                fid = fopen(metaFile, 'r');
                expectedMeta = jsondecode(fread(fid, inf, '*char')');
                fclose(fid);
                testCase.verifyEqual(reader.numframes(epochstreams, epoch_select), ...
                    expectedMeta.numframes, ...
                    ['numframes mismatch against ' SourceType ' artifacts.']);
                fs = reader.framesize(epochstreams, epoch_select);
                testCase.verifyEqual(fs(:)', expectedMeta.framesize(:)', ...
                    ['framesize mismatch against ' SourceType ' artifacts.']);
                testCase.verifyEqual(char(reader.datatype(epochstreams, epoch_select)), ...
                    char(expectedMeta.datatype), ...
                    ['datatype mismatch against ' SourceType ' artifacts.']);
            end

            readFile = fullfile(artifactDir, 'readData.json');
            testCase.verifyTrue(isfile(readFile), ...
                ['readData.json missing in ' SourceType ' artifacts.']);
            if isfile(readFile)
                fid = fopen(readFile, 'r');
                expectedRead = jsondecode(fread(fid, inf, '*char')');
                fclose(fid);
                frame1 = reader.readframes(epochstreams, epoch_select, 1);
                testCase.verifyEqual(double(frame1(:)'), expectedRead.frame_1_pixels(:)', ...
                    'AbsTol', 1e-9, ...
                    ['frame 1 pixel mismatch against ' SourceType ' artifacts.']);
            end
        end
    end
end
