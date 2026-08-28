classdef readPrairieview < matlab.unittest.TestCase
    % READPRAIRIEVIEW - Generate symmetry artifacts for the prairieview reader.
    %
    % Exercises the frame API plus the raster-scan metadata against the
    % checked-in example_data/prairieview directory and dumps JSON artifacts
    % that the Python symmetry test suite re-reads and verifies.
    %
    % Image planes are written as YxX matrices, which jsonencode emits as
    % nested row lists, so the comparison is unambiguous despite MATLAB
    % being column-major and numpy row-major.
    %
    % Mirrors tests/symmetry/make_artifacts/reader/test_read_images.py

    methods (Test)
        function testReadPrairieviewArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', 'matlabArtifacts', ...
                'reader', 'readPrairieview', 'testReadPrairieviewArtifacts');

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            pv_dir = fullfile(ndr.fun.ndrpath(), 'example_data', 'prairieview');
            testCase.assumeTrue(isfolder(pv_dir), ...
                'Example Prairie View directory not available; skipping makeArtifacts test.');

            reader = ndr.reader.prairieview();
            epochstreams = {pv_dir};
            epoch_select = 1;

            % --- metadata ---
            ec = reader.epochclock(epochstreams, epoch_select);
            ecStrings = cell(1, numel(ec));
            for i = 1:numel(ec)
                if ischar(ec{i}) || isstring(ec{i})
                    ecStrings{i} = char(ec{i});
                else
                    try
                        ecStrings{i} = char(ec{i}.type);
                    catch
                        ecStrings{i} = class(ec{i});
                    end
                end
            end

            t0t1 = reader.t0_t1(epochstreams, epoch_select);
            ft   = reader.frametimes(epochstreams, epoch_select);
            m    = reader.metadata(epochstreams, epoch_select);

            % Mirror the Python field names and logical types exactly.
            imageMetadata = struct();
            imageMetadata.israster        = logical(m.israster);
            imageMetadata.frame_period    = m.frame_period;
            imageMetadata.line_period     = m.line_period;
            imageMetadata.dwell_time      = m.dwell_time;
            imageMetadata.lines_per_frame = m.lines_per_frame;
            imageMetadata.pixels_per_line = m.pixels_per_line;
            imageMetadata.bidirectional   = logical(m.bidirectional);

            metadata = struct();
            metadata.numframes      = reader.numframes(epochstreams, epoch_select);
            metadata.framesize      = reader.framesize(epochstreams, epoch_select);
            metadata.dimensionorder = reader.dimensionorder(epochstreams, epoch_select);
            metadata.datatype       = reader.datatype(epochstreams, epoch_select);
            metadata.frametimes     = ft(:)';
            metadata.t0_t1          = t0t1{1}(:)';
            metadata.epochclock     = ecStrings;
            metadata.hasconfigtimes = logical(reader.hasconfigtimes(epochstreams));
            metadata.image_metadata = imageMetadata;

            metaJson = jsonencode(metadata, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'metadata.json'), 'w');
            assert(fid > 0, 'Could not create metadata.json');
            fprintf(fid, '%s', metaJson);
            fclose(fid);

            % --- frames ---
            % Both channels of frame 1, plus a SelectC-restricted read of
            % frame 2, which pins the C-axis ordering and the channel
            % selection path.
            frames = reader.readframes(epochstreams, epoch_select, 1);
            sel    = reader.readframes(epochstreams, epoch_select, 2, 'SelectC', 2);

            readStruct = struct();
            readStruct.frame_1_channel_1 = frames(:,:,1,1,1);
            readStruct.frame_1_channel_2 = frames(:,:,2,1,1);
            readStruct.frame_2_selectC_2 = sel(:,:,1,1,1);

            readJson = jsonencode(readStruct, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'readFrames.json'), 'w');
            assert(fid > 0, 'Could not create readFrames.json');
            fprintf(fid, '%s', readJson);
            fclose(fid);
        end
    end
end
