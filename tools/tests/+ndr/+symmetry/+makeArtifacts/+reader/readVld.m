classdef readVld < matlab.unittest.TestCase
    % READVLD - Generate symmetry artifacts for the VH Lab LabView reader.
    %
    % Reads the checked-in example.vld/.vlh through ndr.reader.vld and dumps
    % JSON artifacts that the Python symmetry test suite re-reads and
    % verifies.
    %
    % Mirrors tests/symmetry/make_artifacts/reader/test_read_vld.py

    methods (Test)
        function testReadVldArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', 'matlabArtifacts', ...
                'reader', 'readVld', 'testReadVldArtifacts');

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            vld_file = fullfile(ndr.fun.ndrpath(), 'example_data', 'example.vld');
            testCase.assumeTrue(isfile(vld_file), ...
                'Example VLD file not available; skipping makeArtifacts test.');

            reader = ndr.reader.vld();
            epochstreams = {vld_file};
            epoch_select = 1;

            s0 = 1;
            s1 = 100;

            % --- metadata ---
            channels = reader.getchannelsepoch(epochstreams, epoch_select);
            sr       = reader.samplerate(epochstreams, epoch_select, 'ai', 1);
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
            metadata.channel_names       = {channels.name};
            metadata.channel_types       = {channels.type};
            metadata.samplerate          = sr;
            metadata.t0_t1               = t0t1{1}(:)';
            metadata.epochclock          = ecStrings;
            metadata.labeling_convention = reader.channelLabelingConvention('analog_in');

            metaJson = jsonencode(metadata, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'metadata.json'), 'w');
            assert(fid > 0, 'Could not create metadata.json');
            fprintf(fid, '%s', metaJson);
            fclose(fid);

            % --- data ---
            % Channels 1 and 3 both land, so the artifact pins the
            % channel->column mapping and not merely the first column.
            ch1  = reader.readchannels_epochsamples('analog_in', 1, epochstreams, epoch_select, s0, s1);
            ch3  = reader.readchannels_epochsamples('analog_in', 3, epochstreams, epoch_select, s0, s1);
            time = reader.readchannels_epochsamples('time', 1, epochstreams, epoch_select, s0, 10);

            readStruct = struct();
            readStruct.ai_channel_1_samples_1_100 = ch1(:)';
            readStruct.ai_channel_3_samples_1_100 = ch3(:)';
            readStruct.time_samples_1_10          = time(:)';

            readJson = jsonencode(readStruct, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'readData.json'), 'w');
            assert(fid > 0, 'Could not create readData.json');
            fprintf(fid, '%s', readJson);
            fclose(fid);
        end
    end
end
