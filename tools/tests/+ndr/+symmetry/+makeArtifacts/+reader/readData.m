classdef readData < matlab.unittest.TestCase
    % READDATA - Generate symmetry artifacts for NDR reader tests.
    %
    % This test reads a small slice of the checked-in Intan RHD example
    % data through ndr.reader.intan_rhd and dumps JSON artifacts that the
    % Python symmetry test suite can re-read and verify.

    methods (Test)
        function testReadDataArtifacts(testCase)
            % Determine the artifact directory (must match NDR-python layout)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', 'matlabArtifacts', ...
                'reader', 'readData', 'testReadDataArtifacts');

            % Clear previous artifacts if they exist
            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            % Locate the example RHD file checked into NDR-matlab
            rhd_file = fullfile(ndr.fun.ndrpath(), 'example_data', 'example.rhd');
            testCase.assumeTrue(isfile(rhd_file), ...
                'Example RHD file not available; skipping makeArtifacts test.');

            % Instantiate the reader and configure the epoch
            reader = ndr.reader.intan_rhd();
            epochstreams = {rhd_file};
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
            metadata.channels    = channels;
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
