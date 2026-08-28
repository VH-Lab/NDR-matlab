classdef readPrairieview < matlab.unittest.TestCase
    % READPRAIRIEVIEW - Verify symmetry artifacts for the prairieview reader.
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
        function testReadPrairieviewArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', SourceType, ...
                'reader', 'readPrairieview', 'testReadPrairieviewArtifacts');

            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            pv_dir = fullfile(ndr.fun.ndrpath(), 'example_data', 'prairieview');
            testCase.assumeTrue(isfolder(pv_dir), ...
                'Example Prairie View directory not available; skipping readArtifacts test.');

            reader = ndr.reader.prairieview();
            epochstreams = {pv_dir};
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

                testCase.verifyEqual(char(reader.datatype(epochstreams, epoch_select)), ...
                    char(expectedMeta.datatype), ...
                    ['datatype mismatch against ' SourceType ' artifacts.']);

                testCase.verifyEqual(logical(reader.hasconfigtimes(epochstreams)), ...
                    logical(expectedMeta.hasconfigtimes), ...
                    ['hasconfigtimes mismatch against ' SourceType ' artifacts.']);

                ft = reader.frametimes(epochstreams, epoch_select);
                testCase.verifyEqual(ft(:)', expectedMeta.frametimes(:)', 'AbsTol', 1e-9, ...
                    ['frametimes mismatch against ' SourceType ' artifacts.']);

                t0t1 = reader.t0_t1(epochstreams, epoch_select);
                testCase.verifyEqual(t0t1{1}(:)', expectedMeta.t0_t1(:)', 'AbsTol', 1e-9, ...
                    ['t0_t1 mismatch against ' SourceType ' artifacts.']);

                % --- raster metadata, field by field ---
                m = reader.metadata(epochstreams, epoch_select);
                e = expectedMeta.image_metadata;

                testCase.verifyEqual(logical(m.israster), logical(e.israster), ...
                    ['israster mismatch against ' SourceType ' artifacts.']);
                testCase.verifyEqual(logical(m.bidirectional), logical(e.bidirectional), ...
                    ['bidirectional mismatch against ' SourceType ' artifacts.']);

                % NaN is written as null by both ports, which jsondecode
                % returns as empty; treat empty and NaN as the same "unknown".
                numericFields = {'frame_period', 'line_period', 'dwell_time', ...
                    'lines_per_frame', 'pixels_per_line'};
                for k = 1:numel(numericFields)
                    f = numericFields{k};
                    actual = m.(f);
                    expected = e.(f);
                    if isempty(expected) || (isnumeric(expected) && all(isnan(expected)))
                        testCase.verifyTrue(isnan(actual), ...
                            [f ' should be NaN against ' SourceType ' artifacts.']);
                    else
                        testCase.verifyEqual(double(actual), double(expected), 'AbsTol', 1e-9, ...
                            [f ' mismatch against ' SourceType ' artifacts.']);
                    end
                end
            else
                disp(['metadata.json not found in ' SourceType ' artifact directory. Skipping metadata check.']);
            end

            % --- frame parity ---
            readFile = fullfile(artifactDir, 'readFrames.json');
            if isfile(readFile)
                fid = fopen(readFile, 'r');
                expectedRead = jsondecode(fread(fid, inf, '*char')');
                fclose(fid);

                frames = reader.readframes(epochstreams, epoch_select, 1);
                testCase.verifyEqual(double(frames(:,:,1,1,1)), double(expectedRead.frame_1_channel_1), ...
                    ['frame 1 channel 1 mismatch against ' SourceType ' artifacts.']);
                testCase.verifyEqual(double(frames(:,:,2,1,1)), double(expectedRead.frame_1_channel_2), ...
                    ['frame 1 channel 2 mismatch against ' SourceType ' artifacts.']);

                sel = reader.readframes(epochstreams, epoch_select, 2, 'SelectC', 2);
                testCase.verifyEqual(double(sel(:,:,1,1,1)), double(expectedRead.frame_2_selectC_2), ...
                    ['SelectC frame mismatch against ' SourceType ' artifacts.']);
            else
                disp(['readFrames.json not found in ' SourceType ' artifact directory. Skipping frame check.']);
            end
        end
    end
end
