classdef (TestTags = {'Symmetry'}) readVideo < matlab.unittest.TestCase
    % READVIDEO - Generate symmetry artifacts for the video reader.
    %
    % Exercises the frame API (numframes, framesize, dimensionorder,
    % datatype, frametimes, t0_t1, epochclock, getchannelsepoch, metadata,
    % readframes) against the checked-in example_video.avi (24-bit RGB) and
    % example_video_grey.avi (8-bit, grey palette) and dumps JSON artifacts
    % that the Python symmetry test suite re-reads and verifies. Both files
    % are uncompressed, so the two ports must agree pixel for pixel even
    % though they decode with different libraries (VideoReader here,
    % PyAV/FFmpeg in Python).
    %
    % Each colour channel is written as its own YxX matrix, which jsonencode
    % emits as nested row lists, so the comparison is unambiguous despite
    % MATLAB being column-major and numpy row-major.
    %
    % Mirrors tests/symmetry/make_artifacts/reader/test_read_video.py

    methods (Test)
        function testReadVideoArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', 'matlabArtifacts', ...
                'reader', 'readVideo', 'testReadVideoArtifacts');

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            rgbFile = fullfile(ndr.fun.ndrpath(), 'example_data', 'example_video.avi');
            greyFile = fullfile(ndr.fun.ndrpath(), 'example_data', 'example_video_grey.avi');
            testCase.assumeTrue(isfile(rgbFile) && isfile(greyFile), ...
                'Example videos not available; skipping makeArtifacts test.');

            reader = ndr.reader.video();
            epoch_select = 1;

            % --- metadata ---
            metadata = struct();
            metadata.rgb = ndr.symmetry.makeArtifacts.reader.readVideo.videoMetadata( ...
                reader, {rgbFile}, epoch_select);
            metadata.grey = ndr.symmetry.makeArtifacts.reader.readVideo.videoMetadata( ...
                reader, {greyFile}, epoch_select);

            metaJson = jsonencode(metadata, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'metadata.json'), 'w');
            assert(fid > 0, 'Could not create metadata.json');
            fprintf(fid, '%s', metaJson);
            fclose(fid);

            % --- frames ---
            % First and last RGB frame, channel by channel; a SelectC read;
            % and an out-of-order greyscale read (the random-access path).
            n = metadata.rgb.numframes;
            frames = reader.readframes({rgbFile}, epoch_select, [1 n]);
            sel = reader.readframes({rgbFile}, epoch_select, 3, 'SelectC', 2);
            greyFrames = reader.readframes({greyFile}, epoch_select, [4 2]);

            readStruct = struct();
            frameNumbers = [1 n];
            for t = 1:2
                for c = 1:3
                    readStruct.(sprintf('rgb_frame_%d_channel_%d', frameNumbers(t), c)) = ...
                        frames(:,:,c,1,t);
                end
            end
            readStruct.rgb_frame_3_selectC_2 = sel(:,:,1,1,1);
            readStruct.grey_frame_4 = greyFrames(:,:,1,1,1);
            readStruct.grey_frame_2 = greyFrames(:,:,1,1,2);

            readJson = jsonencode(readStruct, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'readFrames.json'), 'w');
            assert(fid > 0, 'Could not create readFrames.json');
            fprintf(fid, '%s', readJson);
            fclose(fid);
        end
    end

    methods (Static)
        function metadata = videoMetadata(reader, epochstreams, epoch_select)
            % VIDEOMETADATA - the metadata artifact struct for one video epoch
            arguments
                reader (1,1) ndr.reader.video
                epochstreams cell
                epoch_select (1,1) double
            end
            ec = reader.epochclock(epochstreams, epoch_select);
            ecStrings = cell(1, numel(ec));
            for i = 1:numel(ec)
                ecStrings{i} = char(ec{i}.type);
            end

            t0t1 = reader.t0_t1(epochstreams, epoch_select);
            ft   = reader.frametimes(epochstreams, epoch_select);
            m    = reader.metadata(epochstreams, epoch_select);
            ch   = reader.getchannelsepoch(epochstreams, epoch_select);

            % Mirror the Python field names and logical types exactly.
            imageMetadata = struct();
            imageMetadata.israster        = logical(m.israster);
            imageMetadata.frame_period    = m.frame_period;
            imageMetadata.line_period     = m.line_period;
            imageMetadata.dwell_time      = m.dwell_time;
            imageMetadata.lines_per_frame = m.lines_per_frame;
            imageMetadata.pixels_per_line = m.pixels_per_line;
            imageMetadata.bidirectional   = logical(m.bidirectional);

            channels = struct('name', {ch.name}, 'type', {ch.type});

            metadata = struct();
            metadata.numframes      = reader.numframes(epochstreams, epoch_select);
            metadata.framesize      = reader.framesize(epochstreams, epoch_select);
            metadata.dimensionorder = reader.dimensionorder(epochstreams, epoch_select);
            metadata.datatype       = reader.datatype(epochstreams, epoch_select);
            metadata.frametimes     = ft(:)';
            metadata.t0_t1          = t0t1{1}(:)';
            metadata.epochclock     = ecStrings;
            metadata.channels       = channels;
            metadata.image_metadata = imageMetadata;
        end
    end
end
