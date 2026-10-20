classdef readVideo < matlab.unittest.TestCase
    % READVIDEO - Verify symmetry artifacts for the video reader.
    %
    % Parameterized over the two artifact sources ('matlabArtifacts',
    % 'pythonArtifacts'), so one test verifies parity in both directions.
    % Skips when the artifact directory for a given SourceType is absent.
    %
    % Frame times are compared to 1e-6 s rather than the 1e-9 the TIFF
    % readers use: here each port measures them through its own decoder
    % (VideoReader's CurrentTime here, FFmpeg presentation timestamps in
    % Python) rather than reading the same numbers from a text sidecar, and
    % a microsecond is still far below one frame period. Pixels must match
    % exactly: the files are uncompressed.
    %
    % Mirrors tests/symmetry/read_artifacts/reader/test_read_video.py

    properties (TestParameter)
        SourceType = {'matlabArtifacts', 'pythonArtifacts'};
    end

    properties (Constant)
        TimeTol = 1e-6;
    end

    methods (Test)
        function testReadVideoArtifacts(testCase, SourceType)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', SourceType, ...
                'reader', 'readVideo', 'testReadVideoArtifacts');

            if ~isfolder(artifactDir)
                disp(['Artifact directory from ' SourceType ' does not exist. Skipping.']);
                return;
            end

            rgbFile = fullfile(ndr.fun.ndrpath(), 'example_data', 'example_video.avi');
            greyFile = fullfile(ndr.fun.ndrpath(), 'example_data', 'example_video_grey.avi');
            testCase.assumeTrue(isfile(rgbFile) && isfile(greyFile), ...
                'Example videos not available; skipping readArtifacts test.');

            reader = ndr.reader.video();
            epoch_select = 1;

            % --- metadata parity ---
            metaFile = fullfile(artifactDir, 'metadata.json');
            if isfile(metaFile)
                fid = fopen(metaFile, 'r');
                expectedMeta = jsondecode(fread(fid, inf, '*char')');
                fclose(fid);

                testCase.verifyMetadata(reader, {rgbFile}, epoch_select, ...
                    expectedMeta.rgb, [SourceType ' (rgb)']);
                testCase.verifyMetadata(reader, {greyFile}, epoch_select, ...
                    expectedMeta.grey, [SourceType ' (grey)']);
            else
                disp(['metadata.json not found in ' SourceType ' artifact directory. Skipping metadata check.']);
            end

            % --- frame parity ---
            readFile = fullfile(artifactDir, 'readFrames.json');
            if isfile(readFile)
                fid = fopen(readFile, 'r');
                expectedRead = jsondecode(fread(fid, inf, '*char')');
                fclose(fid);

                n = reader.numframes({rgbFile}, epoch_select);
                frames = reader.readframes({rgbFile}, epoch_select, [1 n]);
                frameNumbers = [1 n];
                for t = 1:2
                    for c = 1:3
                        key = sprintf('rgb_frame_%d_channel_%d', frameNumbers(t), c);
                        testCase.verifyEqual(double(frames(:,:,c,1,t)), double(expectedRead.(key)), ...
                            [key ' mismatch against ' SourceType ' artifacts.']);
                    end
                end

                sel = reader.readframes({rgbFile}, epoch_select, 3, 'SelectC', 2);
                testCase.verifyEqual(double(sel(:,:,1,1,1)), double(expectedRead.rgb_frame_3_selectC_2), ...
                    ['SelectC frame mismatch against ' SourceType ' artifacts.']);

                greyFrames = reader.readframes({greyFile}, epoch_select, [4 2]);
                testCase.verifyEqual(double(greyFrames(:,:,1,1,1)), double(expectedRead.grey_frame_4), ...
                    ['grey frame 4 mismatch against ' SourceType ' artifacts.']);
                testCase.verifyEqual(double(greyFrames(:,:,1,1,2)), double(expectedRead.grey_frame_2), ...
                    ['grey frame 2 mismatch against ' SourceType ' artifacts.']);
            else
                disp(['readFrames.json not found in ' SourceType ' artifact directory. Skipping frame check.']);
            end
        end
    end

    methods
        function verifyMetadata(testCase, reader, epochstreams, epoch_select, e, label)
            % VERIFYMETADATA - compare one video epoch against its metadata artifact
            arguments
                testCase (1,1) matlab.unittest.TestCase
                reader (1,1) ndr.reader.video
                epochstreams cell
                epoch_select (1,1) double
                e (1,1) struct
                label {mustBeTextScalar}
            end
            label = char(label);

            testCase.verifyEqual(double(reader.numframes(epochstreams, epoch_select)), ...
                double(e.numframes), ['numframes mismatch against ' label ' artifacts.']);
            testCase.verifyEqual(double(reader.framesize(epochstreams, epoch_select)), ...
                double(e.framesize(:)'), ['framesize mismatch against ' label ' artifacts.']);
            testCase.verifyEqual(char(reader.dimensionorder(epochstreams, epoch_select)), ...
                char(e.dimensionorder), ['dimensionorder mismatch against ' label ' artifacts.']);
            % Strict string parity: both ports report the MATLAB class name.
            testCase.verifyEqual(char(reader.datatype(epochstreams, epoch_select)), ...
                char(e.datatype), ['datatype mismatch against ' label ' artifacts.']);

            ft = reader.frametimes(epochstreams, epoch_select);
            testCase.verifyEqual(ft(:)', e.frametimes(:)', 'AbsTol', testCase.TimeTol, ...
                ['frametimes mismatch against ' label ' artifacts.']);
            t0t1 = reader.t0_t1(epochstreams, epoch_select);
            testCase.verifyEqual(t0t1{1}(:)', e.t0_t1(:)', 'AbsTol', testCase.TimeTol, ...
                ['t0_t1 mismatch against ' label ' artifacts.']);

            ec = reader.epochclock(epochstreams, epoch_select);
            ecStrings = cell(1, numel(ec));
            for i = 1:numel(ec)
                ecStrings{i} = char(ec{i}.type);
            end
            testCase.verifyEqual(ecStrings, cellstr(e.epochclock)', ...
                ['epochclock mismatch against ' label ' artifacts.']);

            ch = reader.getchannelsepoch(epochstreams, epoch_select);
            testCase.verifyEqual({ch.name}, {e.channels.name}, ...
                ['channel names mismatch against ' label ' artifacts.']);
            testCase.verifyEqual({ch.type}, {e.channels.type}, ...
                ['channel types mismatch against ' label ' artifacts.']);

            % --- image metadata, field by field ---
            m = reader.metadata(epochstreams, epoch_select);
            im = e.image_metadata;
            testCase.verifyEqual(logical(m.israster), logical(im.israster), ...
                ['israster mismatch against ' label ' artifacts.']);
            testCase.verifyEqual(logical(m.bidirectional), logical(im.bidirectional), ...
                ['bidirectional mismatch against ' label ' artifacts.']);
            % NaN is written as null by both ports, which jsondecode returns
            % as empty; treat empty and NaN as the same "unknown".
            numericFields = {'frame_period', 'line_period', 'dwell_time', ...
                'lines_per_frame', 'pixels_per_line'};
            for k = 1:numel(numericFields)
                f = numericFields{k};
                actual = m.(f);
                expected = im.(f);
                if isempty(expected) || (isnumeric(expected) && all(isnan(expected)))
                    testCase.verifyTrue(isnan(actual), ...
                        [f ' should be NaN against ' label ' artifacts.']);
                else
                    testCase.verifyEqual(double(actual), double(expected), 'AbsTol', 1e-9, ...
                        [f ' mismatch against ' label ' artifacts.']);
                end
            end
        end
    end
end
