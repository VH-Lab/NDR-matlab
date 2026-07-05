classdef readData_prairieview < matlab.unittest.TestCase
    % READDATA_PRAIRIEVIEW - Generate symmetry artifacts for the NDR prairieview reader.
    %
    % This test reads the checked-in Prairie View 2p example recording (a
    % directory: one TIFF per frame + a config companion) through
    % ndr.reader.prairieview and dumps JSON artifacts that the Python symmetry
    % test suite can re-read and verify. It proves that NDR-matlab and
    % NDR-python read the same Prairie View epoch identically.
    %
    % prairieview is a FRAME/IMAGE reader: it exposes the frame API
    % (numframes/framesize/datatype/dimensionorder/frametimes/readframes/
    % epochclock/t0_t1), NOT channels/samplerate.
    %
    % Add this method to
    %   tools/tests/+ndr/+symmetry/+makeArtifacts/+reader/
    % (mirrors the intan readData.m generator).

    methods (Test)
        function testReadDataPrairieviewArtifacts(testCase)
            % Determine the artifact directory (must match NDR-python layout)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', 'matlabArtifacts', ...
                'reader', 'readData', 'testReadDataPrairieviewArtifacts');

            % Clear previous artifacts if they exist
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            % Locate the example Prairie View directory checked into NDR-matlab
            pv_dir = fullfile(ndr.fun.ndrpath(), 'example_data', 'prairieview_example');
            testCase.assumeTrue(isfolder(pv_dir), ...
                'Example Prairie View directory not available; skipping makeArtifacts test.');

            % Instantiate the reader and configure the epoch (directory epoch)
            reader = ndr.reader.prairieview();
            epochstreams = {pv_dir};
            epoch_select = 1;

            % Collect frame-API metadata
            numframes      = reader.numframes(epochstreams, epoch_select);
            framesize      = reader.framesize(epochstreams, epoch_select);
            datatype       = reader.datatype(epochstreams, epoch_select);
            dimensionorder = reader.dimensionorder(epochstreams, epoch_select);
            frametimes     = reader.frametimes(epochstreams, epoch_select);
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
            metadata.frametimes     = frametimes(:)';
            metadata.t0_t1          = t0t1{1};
            metadata.epochclock     = ecStrings;

            metaJson = jsonencode(metadata, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'metadata.json'), 'w');
            assert(fid > 0, 'Could not create metadata.json');
            fprintf(fid, '%s', metaJson);
            fclose(fid);

            % Read frame 1 (1-based), all channels, for pixel parity checks.
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
