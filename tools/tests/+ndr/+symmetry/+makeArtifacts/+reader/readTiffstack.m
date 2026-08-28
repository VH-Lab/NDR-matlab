classdef readTiffstack < matlab.unittest.TestCase
    % READTIFFSTACK - Generate symmetry artifacts for the tiffstack reader.
    %
    % Exercises the frame API (numframes, framesize, dimensionorder,
    % datatype, frametimes, readframes) against the checked-in
    % example_movie.tif and dumps JSON artifacts that the Python symmetry
    % test suite re-reads and verifies.
    %
    % Image planes are written as YxX matrices, which jsonencode emits as
    % nested row lists, so the comparison is unambiguous despite MATLAB
    % being column-major and numpy row-major.
    %
    % Mirrors tests/symmetry/make_artifacts/reader/test_read_images.py

    methods (Test)
        function testReadTiffstackArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', 'matlabArtifacts', ...
                'reader', 'readTiffstack', 'testReadTiffstackArtifacts');

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            movie_file = fullfile(ndr.fun.ndrpath(), 'example_data', 'example_movie.tif');
            testCase.assumeTrue(isfile(movie_file), ...
                'Example TIFF movie not available; skipping makeArtifacts test.');

            reader = ndr.reader.tiffstack();
            epochstreams = {movie_file};
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

            metadata = struct();
            metadata.numframes      = reader.numframes(epochstreams, epoch_select);
            metadata.framesize      = reader.framesize(epochstreams, epoch_select);
            metadata.dimensionorder = reader.dimensionorder(epochstreams, epoch_select);
            metadata.datatype       = reader.datatype(epochstreams, epoch_select);
            metadata.frametimes     = ft(:)';
            metadata.t0_t1          = t0t1{1}(:)';
            metadata.epochclock     = ecStrings;
            metadata.hasframetimes  = logical(reader.hasframetimes(epochstreams));

            metaJson = jsonencode(metadata, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'metadata.json'), 'w');
            assert(fid > 0, 'Could not create metadata.json');
            fprintf(fid, '%s', metaJson);
            fclose(fid);

            % --- frames ---
            frames = reader.readframes(epochstreams, epoch_select, [1 5]);

            readStruct = struct();
            readStruct.frame_1 = frames(:,:,1,1,1);
            readStruct.frame_5 = frames(:,:,1,1,2);

            readJson = jsonencode(readStruct, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'readFrames.json'), 'w');
            assert(fid > 0, 'Could not create readFrames.json');
            fprintf(fid, '%s', readJson);
            fclose(fid);
        end
    end
end
