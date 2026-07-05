classdef readData_tiffstack < matlab.unittest.TestCase
    % READDATA_TIFFSTACK - Generate symmetry artifacts for the NDR tiffstack reader.
    %
    % This test reads the checked-in multipage-TIFF example stack through
    % ndr.reader.tiffstack and dumps JSON artifacts that the Python symmetry
    % test suite can re-read and verify. It proves that NDR-matlab and
    % NDR-python read the same .tif stack identically.
    %
    % tiffstack is a FRAME/IMAGE reader: it exposes the frame API
    % (numframes/framesize/datatype/dimensionorder/frametimes/readframes/
    % epochclock/t0_t1), NOT channels/samplerate.
    %
    % Add this method to
    %   tools/tests/+ndr/+symmetry/+makeArtifacts/+reader/
    % (mirrors the intan readData.m generator).

    methods (Test)
        function testReadDataTiffstackArtifacts(testCase)
            % Determine the artifact directory (must match NDR-python layout)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', 'matlabArtifacts', ...
                'reader', 'readData', 'testReadDataTiffstackArtifacts');

            % Clear previous artifacts if they exist
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            % Locate the example TIFF stack checked into NDR-matlab
            tiff_file = fullfile(ndr.fun.ndrpath(), 'example_data', 'tiffstack_example.tif');
            testCase.assumeTrue(isfile(tiff_file), ...
                'Example TIFF file not available; skipping makeArtifacts test.');

            % Instantiate the reader and configure the epoch
            reader = ndr.reader.tiffstack();
            epochstreams = {tiff_file};
            epoch_select = 1;

            % Collect frame-API metadata
            numframes      = reader.numframes(epochstreams, epoch_select);
            framesize      = reader.framesize(epochstreams, epoch_select);
            datatype       = reader.datatype(epochstreams, epoch_select);
            dimensionorder = reader.dimensionorder(epochstreams, epoch_select);
            t0t1           = reader.t0_t1(epochstreams, epoch_select);
            ec             = reader.epochclock(epochstreams, epoch_select);

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

            metadata = struct();
            metadata.numframes      = numframes;
            metadata.framesize      = framesize(:)';
            metadata.datatype       = datatype;
            metadata.dimensionorder = dimensionorder;
            metadata.epochclock     = ecStrings;
            metadata.t0_t1          = t0t1{1};

            metaJson = jsonencode(metadata, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'metadata.json'), 'w');
            assert(fid > 0, 'Could not create metadata.json');
            fprintf(fid, '%s', metaJson);
            fclose(fid);

            % Read frame 1 (1-based) for pixel parity checks; flatten to a row.
            frame1 = reader.readframes(epochstreams, epoch_select, 1);

            readStruct = struct();
            readStruct.frame_1_pixels = double(frame1(:)');

            readJson = jsonencode(readStruct, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'readData.json'), 'w');
            assert(fid > 0, 'Could not create readData.json');
            fprintf(fid, '%s', readJson);
            fclose(fid);
        end
    end
end
