classdef readSpikeGadgets < matlab.unittest.TestCase
    % READSPIKEGADGETS - Generate symmetry artifacts for the SpikeGadgets format layer.
    %
    % Compares at the ndr.format.spikegadgets level rather than through
    % ndr.reader.spikegadgets_rec, because the Python port's reader class is
    % still a stub; its format functions are what actually read the file.
    %
    % These artifacts are deliberately alignment-sensitive. A .rec is a stream
    % of fixed-size packets, so both the offset of the first packet and the
    % stride between packets have to be exactly right; get either wrong and the
    % values stay in range and the arrays keep their shape, so nothing but a
    % byte-for-byte comparison notices. Samples are captured from s0 = 1 and
    % again from s0 = 1001, since an s0-dependent error is invisible at the
    % start of the file.

    methods (Test)
        function testReadSpikeGadgetsArtifacts(testCase)
            artifactDir = fullfile(tempdir(), 'NDR', 'symmetryTest', 'matlabArtifacts', ...
                'format', 'readSpikeGadgets', 'testReadSpikeGadgetsArtifacts');

            if isfolder(artifactDir)
                rmdir(artifactDir, 's');
            end
            mkdir(artifactDir);

            rec_file = fullfile(ndr.fun.ndrpath(), 'example_data', 'example.rec');
            testCase.assumeTrue(isfile(rec_file), ...
                'Example .rec file not available; skipping makeArtifacts test.');

            config = ndr.format.spikegadgets.read_rec_config(rec_file);
            numChannels  = str2double(config.numChannels);
            headerSize   = str2double(config.headerSize);
            samplingRate = str2double(config.samplingRate);

            metadata = struct();
            metadata.numChannels  = numChannels;
            metadata.headerSize   = headerSize;
            metadata.samplingRate = samplingRate;

            metaJson = jsonencode(metadata, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'metadata.json'), 'w');
            assert(fid > 0, 'Could not create metadata.json');
            fprintf(fid, '%s', metaJson);
            fclose(fid);

            readStruct = struct();

            % Trode channel 1, from the start of the file.
            [data1, ts1] = ndr.format.spikegadgets.read_rec_trodeChannels(rec_file, ...
                config.numChannels, 1, samplingRate, config.headerSize, 1, 100);
            readStruct.trode_channel_1_samples_1_100 = double(data1(:))';
            readStruct.trode_timestamps_samples_1_100 = double(ts1(:))';

            % The same channel from s0 = 1001. An error in the seek to s0
            % scales with s0, so it does not show up in the first read.
            data2 = ndr.format.spikegadgets.read_rec_trodeChannels(rec_file, ...
                config.numChannels, 1, samplingRate, config.headerSize, 1001, 1100);
            readStruct.trode_channel_1_samples_1001_1100 = double(data2(:))';

            % A second channel, to catch a drift that lands on a neighbour.
            data3 = ndr.format.spikegadgets.read_rec_trodeChannels(rec_file, ...
                config.numChannels, 2, samplingRate, config.headerSize, 1, 100);
            readStruct.trode_channel_2_samples_1_100 = double(data3(:))';

            readJson = jsonencode(readStruct, 'ConvertInfAndNaN', true, 'PrettyPrint', true);
            fid = fopen(fullfile(artifactDir, 'readData.json'), 'w');
            assert(fid > 0, 'Could not create readData.json');
            fprintf(fid, '%s', readJson);
            fclose(fid);

            testCase.verifyTrue(isfile(fullfile(artifactDir, 'readData.json')));
        end
    end
end
