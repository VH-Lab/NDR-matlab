classdef readData_vld < matlab.unittest.TestCase
    % READDATA_VLD - Generate symmetry artifacts for the NDR vld reader.
    %
    % This test reads a small slice of the checked-in VHLAB LabView (.vld)
    % example data through ndr.reader.vld and dumps JSON artifacts that the
    % Python symmetry test suite can re-read and verify. It proves that
    % NDR-matlab and NDR-python read the same .vld file identically.
    %
    % Add this method to
    %   tools/tests/+ndr/+symmetry/+makeArtifacts/+reader/
    % (mirrors the intan readData.m generator).

    methods (Test)
        function testReadDataVldArtifacts(testCase)
            % Determine the artifact directory (must match NDR-python layout)
            % NOTE: the artifact folder name must match what the NDR-python
            % read_artifacts test re-reads: tests/symmetry/read_artifacts/
            % reader/test_read_data_vld.py uses 'testReadDataVldArtifacts' (NOT
            % the test-method name). Keep these in lock-step.
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', 'matlabArtifacts', ...
                'reader', 'readData', 'testReadDataVldArtifacts');

            % Clear previous artifacts if they exist
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            % Locate the example VLD file checked into NDR-matlab
            vld_file = fullfile(ndr.fun.ndrpath(), 'example_data', 'vld_example.vld');
            testCase.assumeTrue(isfile(vld_file), ...
                'Example VLD file not available; skipping makeArtifacts test.');

            % Instantiate the reader and configure the epoch
            reader = ndr.reader.vld();
            epochstreams = {vld_file};
            epoch_select = 1;
            channeltype = 'ai';
            channel = 1;

            % Collect metadata
            channels = reader.getchannelsepoch(epochstreams, epoch_select);
            sr       = reader.samplerate(epochstreams, epoch_select, channeltype, channel);
            t0t1     = reader.t0_t1(epochstreams, epoch_select);
            ec       = reader.epochclock(epochstreams, epoch_select);

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
            metadata.n_channels  = numel(channels);
            metadata.samplerate  = sr;
            metadata.t0_t1       = t0t1{1};
            metadata.epochclock  = ecStrings;

            metaJson = jsonencode(metadata, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'metadata.json'), 'w');
            assert(fid > 0, 'Could not create metadata.json');
            fprintf(fid, '%s', metaJson);
            fclose(fid);

            % Read a short, deterministic chunk of samples for numerical parity checks
            s0 = 1;
            s1 = 100;
            data = reader.readchannels_epochsamples(channeltype, channel, ...
                epochstreams, epoch_select, s0, s1);

            readStruct = struct();
            readStruct.ai_channel_1_samples_1_100 = data(:)';

            readJson = jsonencode(readStruct, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'readData.json'), 'w');
            assert(fid > 0, 'Could not create readData.json');
            fprintf(fid, '%s', readJson);
            fclose(fid);
        end
    end
end
