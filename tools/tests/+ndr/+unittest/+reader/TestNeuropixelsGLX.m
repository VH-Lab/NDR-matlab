classdef TestNeuropixelsGLX < matlab.unittest.TestCase
%TESTNEUROPIXELSGLX Unit tests for ndr.reader.neuropixelsGLX.
%
%   This test class generates temporary SpikeGLX-format files (.ap.bin and
%   .ap.meta) with known properties and verifies that the reader correctly
%   parses metadata, reports channels, returns sample rates, and reads data.
%
%   Tests are parameterized over different channel counts to verify correct
%   handling of both full 384-channel recordings and reduced channel subsets
%   (e.g., when the user saves fewer than all channels).
%
%   Example:
%       results = runtests('ndr.unittest.reader.TestNeuropixelsGLX');

    properties (Constant)
        SR = 30000;          % Sample rate (Hz)
        NumSamples = 1000;   % Samples per channel in test file
    end

    properties (ClassSetupParameter)
        % Test with different channel counts to cover subset case
        NumNeuralChans = struct('full', 384, 'subset', 32, 'small', 8);
    end

    properties (SetAccess=protected)
        TempDir char = ''
        MetaFilename char = ''
        BinFilename char = ''
        NumNeuralChansActual double = NaN
        NumTotalChans double = NaN  % neural + sync
        Reader
    end

    methods (TestClassSetup)
        function setupOnce(testCase, NumNeuralChans)
            disp('Setting up Neuropixels GLX test files...');

            testCase.TempDir = fullfile(tempdir, ['ndr_npx_test_' char(java.util.UUID.randomUUID)]);
            mkdir(testCase.TempDir);

            testCase.NumNeuralChansActual = NumNeuralChans;
            testCase.NumTotalChans = NumNeuralChans + 1; % +1 for sync

            % Create a subdirectory mimicking SpikeGLX structure
            subdir = fullfile(testCase.TempDir, 'test_g0', 'test_g0_imec0');
            mkdir(subdir);

            testCase.MetaFilename = fullfile(subdir, 'test_g0_t0.imec0.ap.meta');
            testCase.BinFilename = fullfile(subdir, 'test_g0_t0.imec0.ap.bin');

            % Generate test data: each neural channel i has values
            % (i-1)*50 + (1:NumSamples), sync channel is all zeros.
            % Step of 50 keeps max value (383*50+1000=20150) within int16 range.
            nSamples = testCase.NumSamples;
            nTotal = testCase.NumTotalChans;
            data = zeros(nSamples, nTotal, 'int16');

            for c = 1:NumNeuralChans
                start_val = (c-1) * 50 + 1;
                end_val = start_val + nSamples - 1;
                data(:, c) = int16(start_val:end_val)';
            end
            % Sync channel (last) stays zeros

            % Write binary file (interleaved int16, no header)
            fid = fopen(testCase.BinFilename, 'w', 'ieee-le');
            testCase.assertNotEqual(fid, -1, 'Could not open bin file for writing.');
            % Interleave: transpose so channels are rows, then linearize
            interleaved = reshape(data', 1, []);
            count = fwrite(fid, interleaved, 'int16');
            fclose(fid);
            testCase.assertEqual(count, numel(interleaved), 'Wrong number of samples written.');

            % Write meta file
            fileSizeBytes = nSamples * nTotal * 2;
            fileTimeSecs = nSamples / testCase.SR;

            % Build channel subset string
            if NumNeuralChans < 384
                % Simulate a subset: channels 0:(NumNeuralChans-1) plus sync at 384
                chan_str = sprintf('0:%d,384', NumNeuralChans - 1);
            else
                chan_str = 'all';
            end

            % Build imroTbl with per-channel gains
            imro_header = sprintf('(0,%d)', NumNeuralChans);
            imro_entries = '';
            for c = 0:(NumNeuralChans-1)
                imro_entries = [imro_entries sprintf('(%d 0 0 500 250 1)', c)]; %#ok<AGROW>
            end

            fid = fopen(testCase.MetaFilename, 'w');
            testCase.assertNotEqual(fid, -1, 'Could not open meta file for writing.');
            fprintf(fid, 'imSampRate=%g\n', testCase.SR);
            fprintf(fid, 'nSavedChans=%d\n', nTotal);
            fprintf(fid, 'snsApLfSy=%d,0,1\n', NumNeuralChans);
            fprintf(fid, 'snsSaveChanSubset=%s\n', chan_str);
            fprintf(fid, 'fileSizeBytes=%d\n', fileSizeBytes);
            fprintf(fid, 'fileTimeSecs=%.6f\n', fileTimeSecs);
            fprintf(fid, 'imAiRangeMax=0.6\n');
            fprintf(fid, 'imAiRangeMin=-0.6\n');
            fprintf(fid, 'imMaxInt=512\n');
            fprintf(fid, 'imDatPrb_type=0\n');
            fprintf(fid, 'imDatPrb_sn=1234567890\n');
            fprintf(fid, 'typeThis=imec\n');
            fprintf(fid, 'imroTbl=%s%s\n', imro_header, imro_entries);
            fclose(fid);

            % Create the reader
            testCase.Reader = ndr.reader.neuropixelsGLX();

            disp(['Created test files with ' num2str(NumNeuralChans) ' neural channels.']);
        end
    end

    methods (TestClassTeardown)
        function teardownOnce(testCase)
            if ~isempty(testCase.TempDir) && isfolder(testCase.TempDir)
                try
                    rmdir(testCase.TempDir, 's');
                catch ME
                    warning('Could not remove temp dir %s: %s', testCase.TempDir, ME.message);
                end
            end
        end
    end

    % --- Test Methods ---

    methods (Test)

        function testReadMeta(testCase)
            %TESTREADMETA Verify meta file parsing returns expected fields.
            meta = ndr.format.neuropixelsGLX.readmeta(testCase.MetaFilename);

            testCase.verifyTrue(isfield(meta, 'imSampRate'), 'Missing imSampRate field.');
            testCase.verifyTrue(isfield(meta, 'nSavedChans'), 'Missing nSavedChans field.');
            testCase.verifyTrue(isfield(meta, 'snsApLfSy'), 'Missing snsApLfSy field.');
            testCase.verifyEqual(str2double(meta.imSampRate), testCase.SR, 'Wrong sample rate in meta.');
            testCase.verifyEqual(str2double(meta.nSavedChans), testCase.NumTotalChans, 'Wrong nSavedChans.');
        end

        function testHeader(testCase)
            %TESTHEADER Verify header parsing extracts correct parameters.
            info = ndr.format.neuropixelsGLX.header(testCase.MetaFilename);

            testCase.verifyEqual(info.sample_rate, testCase.SR, 'Wrong sample rate.');
            testCase.verifyEqual(info.n_saved_chans, testCase.NumTotalChans, 'Wrong n_saved_chans.');
            testCase.verifyEqual(info.n_neural_chans, testCase.NumNeuralChansActual, 'Wrong n_neural_chans.');
            testCase.verifyEqual(info.n_sync_chans, 1, 'Wrong n_sync_chans.');
            testCase.verifyEqual(info.stream_type, 'ap', 'Wrong stream type.');
            testCase.verifyEqual(info.voltage_range, [-0.6 0.6], 'Wrong voltage range.');
            testCase.verifyEqual(info.max_int, 512, 'Wrong max int.');
            testCase.verifyEqual(info.bits_per_sample, 16, 'Wrong bits per sample.');
            testCase.verifyEqual(info.probe_type, '0', 'Wrong probe type.');
        end

        function testGetChannelsEpoch(testCase)
            %TESTGETCHANNELSEPOCH Verify channel listing.
            channels = testCase.Reader.getchannelsepoch({testCase.MetaFilename}, 1);

            % Should have: 1 time + N neural + 1 sync = N+2
            expectedTotal = testCase.NumNeuralChansActual + 2;
            testCase.verifyNumElements(channels, expectedTotal, 'Wrong number of channels.');

            % First channel should be time
            testCase.verifyEqual(channels(1).name, 't1', 'First channel should be t1.');
            testCase.verifyEqual(channels(1).type, 'time', 'First channel type should be time.');

            % Neural channels
            for i = 1:testCase.NumNeuralChansActual
                testCase.verifyEqual(channels(i+1).name, ['ai' int2str(i)], ...
                    ['Wrong name for neural channel ' int2str(i)]);
                testCase.verifyEqual(channels(i+1).type, 'analog_in', ...
                    ['Wrong type for neural channel ' int2str(i)]);
            end

            % Sync channel (last)
            testCase.verifyEqual(channels(end).name, 'di1', 'Last channel should be di1.');
            testCase.verifyEqual(channels(end).type, 'digital_in', 'Last channel type should be digital_in.');
        end

        function testSampleRate(testCase)
            %TESTSAMPLERATE Verify sample rate for all channel types.
            sr_ai = testCase.Reader.samplerate({testCase.MetaFilename}, 1, 'analog_in', 1:3);
            testCase.verifyEqual(sr_ai, repmat(testCase.SR, 1, 3), 'Wrong sample rate for analog_in.');

            sr_t = testCase.Reader.samplerate({testCase.MetaFilename}, 1, 'time', 1);
            testCase.verifyEqual(sr_t, testCase.SR, 'Wrong sample rate for time.');

            sr_di = testCase.Reader.samplerate({testCase.MetaFilename}, 1, 'digital_in', 1);
            testCase.verifyEqual(sr_di, testCase.SR, 'Wrong sample rate for digital_in.');
        end

        function testEpochClock(testCase)
            %TESTEPOCHCLOCK Verify clock type.
            ec = testCase.Reader.epochclock({testCase.MetaFilename}, 1);
            testCase.verifyNumElements(ec, 1, 'Expected one clock type.');
            testCase.verifyEqual(ec{1}.type, 'dev_local_time', 'Expected dev_local_time clock.');
        end

        function testT0T1(testCase)
            %TESTT0T1 Verify epoch time range.
            t0t1 = testCase.Reader.t0_t1({testCase.MetaFilename}, 1);

            expected_t0 = 0;
            expected_t1 = (testCase.NumSamples - 1) / testCase.SR;

            testCase.verifyNumElements(t0t1, 1, 't0_t1 should return 1-element cell.');
            testCase.verifySize(t0t1{1}, [1 2], 't0_t1{1} should be 1x2.');
            testCase.verifyEqual(t0t1{1}(1), expected_t0, 'AbsTol', 1e-9, 'Wrong t0.');
            testCase.verifyEqual(t0t1{1}(2), expected_t1, 'AbsTol', 1e-9, 'Wrong t1.');
        end

        function testUnderlyingDatatype(testCase)
            %TESTUNDERLYINGDATATYPE Verify data type info.
            [dtype, p, dsize] = testCase.Reader.underlying_datatype(...
                {testCase.MetaFilename}, 1, 'analog_in', [1 2]);
            testCase.verifyEqual(dtype, 'int16', 'Wrong datatype for analog_in.');
            testCase.verifyEqual(p, repmat([0 1], 2, 1), 'Wrong polynomial for analog_in.');
            testCase.verifyEqual(dsize, 16, 'Wrong datasize for analog_in.');

            [dtype_t, p_t, dsize_t] = testCase.Reader.underlying_datatype(...
                {testCase.MetaFilename}, 1, 'time', 1);
            testCase.verifyEqual(dtype_t, 'double', 'Wrong datatype for time.');
            testCase.verifyEqual(p_t, [0 1], 'Wrong polynomial for time.');
            testCase.verifyEqual(dsize_t, 64, 'Wrong datasize for time.');
        end

        function testReadAllChannels(testCase)
            %TESTREADALLCHANNELS Verify reading all neural channels.
            nChans = testCase.NumNeuralChansActual;
            s0 = 10;
            s1 = 59;
            numSamplesRead = s1 - s0 + 1;

            data = testCase.Reader.readchannels_epochsamples('analog_in', 1:nChans, ...
                {testCase.MetaFilename}, 1, s0, s1);

            testCase.verifyClass(data, 'int16', 'Data should be int16.');
            testCase.verifySize(data, [numSamplesRead, nChans], 'Wrong data size.');

            % Verify data content
            for c = 1:nChans
                expected_start = int16((c-1) * 50 + s0);
                expected_end = int16((c-1) * 50 + s1);
                testCase.verifyEqual(data(1, c), expected_start, ...
                    ['Wrong first sample for channel ' int2str(c)]);
                testCase.verifyEqual(data(end, c), expected_end, ...
                    ['Wrong last sample for channel ' int2str(c)]);
                testCase.verifyEqual(data(:, c), int16(expected_start:expected_end)', ...
                    ['Wrong data sequence for channel ' int2str(c)]);
            end
        end

        function testReadChannelSubset(testCase)
            %TESTREADCHANNELSUBSET Verify reading a subset of channels.
            nChans = testCase.NumNeuralChansActual;
            channelsToRead = [1, min(3, nChans)];
            s0 = 100;
            s1 = 149;
            numSamplesRead = s1 - s0 + 1;

            data = testCase.Reader.readchannels_epochsamples('analog_in', channelsToRead, ...
                {testCase.MetaFilename}, 1, s0, s1);

            testCase.verifyClass(data, 'int16', 'Data should be int16.');
            testCase.verifySize(data, [numSamplesRead, numel(channelsToRead)], 'Wrong data size.');

            for k = 1:numel(channelsToRead)
                c = channelsToRead(k);
                expected_start = int16((c-1) * 50 + s0);
                expected_end = int16((c-1) * 50 + s1);
                testCase.verifyEqual(data(:, k), int16(expected_start:expected_end)', ...
                    ['Wrong data for channel ' int2str(c)]);
            end
        end

        function testReadTime(testCase)
            %TESTREADTIME Verify time channel returns correct values.
            s0 = 1;
            s1 = 100;
            numSamplesRead = s1 - s0 + 1;

            time = testCase.Reader.readchannels_epochsamples('time', 1, ...
                {testCase.MetaFilename}, 1, s0, s1);

            testCase.verifyClass(time, 'double', 'Time should be double.');
            testCase.verifySize(time, [numSamplesRead, 1], 'Wrong time vector size.');

            expected_t_start = (s0 - 1) / testCase.SR;
            expected_t_end = (s1 - 1) / testCase.SR;
            testCase.verifyEqual(time(1), expected_t_start, 'AbsTol', 1e-9, 'Wrong start time.');
            testCase.verifyEqual(time(end), expected_t_end, 'AbsTol', 1e-9, 'Wrong end time.');
        end

        function testReadSyncChannel(testCase)
            %TESTREADSYNC Verify sync channel reads as zeros.
            s0 = 1;
            s1 = 50;

            data = testCase.Reader.readchannels_epochsamples('digital_in', 1, ...
                {testCase.MetaFilename}, 1, s0, s1);

            testCase.verifyClass(data, 'int16', 'Sync data should be int16.');
            testCase.verifySize(data, [50, 1], 'Wrong sync data size.');
            testCase.verifyEqual(data, int16(zeros(50, 1)), 'Sync channel should be all zeros.');
        end

        function testSamples2Volts(testCase)
            %TESTSAMPLES2VOLTS Verify voltage conversion.
            info = ndr.format.neuropixelsGLX.header(testCase.MetaFilename);

            % Create a known int16 value and convert
            raw = int16([512; -512; 0; 256]);
            volts = ndr.format.neuropixelsGLX.samples2volts(raw, info);

            % Official formula: raw * imAiRangeMax / imMaxInt / gain
            scale = 0.6 / (512 * 500);
            expected = double(raw) * scale;

            testCase.verifyEqual(volts, expected, 'AbsTol', 1e-12, 'Wrong voltage conversion.');
        end

        function testFilenamefromEpochfiles(testCase)
            %TESTFILENAMEFROMEPOCHFILES Verify meta file identification.
            files = {testCase.BinFilename, testCase.MetaFilename, '/some/other/file.txt'};
            result = testCase.Reader.filenamefromepochfiles(files);
            testCase.verifyEqual(result, testCase.MetaFilename, 'Wrong file identified.');

            % Should error with no meta file
            testCase.verifyError(@() testCase.Reader.filenamefromepochfiles({'/no/meta.bin'}), ...
                'ndr:reader:neuropixelsGLX:NoMetaFile');
        end

        function testDaqchannels2InternalChannels(testCase)
            %TESTDAQCHANNELS2INTERNALCHANNELS Verify channel struct conversion.
            channelstruct = testCase.Reader.daqchannels2internalchannels(...
                {'ai', 'ai'}, [1 2], {testCase.MetaFilename}, 1);

            testCase.verifyNumElements(channelstruct, 2, 'Should return 2 channel structs.');
            testCase.verifyEqual(channelstruct(1).internal_channelname, 'ai1');
            testCase.verifyEqual(channelstruct(2).internal_channelname, 'ai2');
            testCase.verifyEqual(channelstruct(1).samplerate, testCase.SR);
        end

        function testFormatReadFunction(testCase)
            %TESTFORMATREAD Verify the format-level read function.
            [data, t, t0_t1_range] = ndr.format.neuropixelsGLX.read(...
                testCase.BinFilename, 0, 0.001, ...
                'numChans', testCase.NumTotalChans, ...
                'SR', testCase.SR, ...
                'channels', 1:2, ...
                'scale', false);

            testCase.verifyClass(data, 'int16', 'Format read should return int16 when scale is false.');
            testCase.verifySize(data, [size(data,1), 2], 'Should have 2 columns.');
            testCase.verifyGreaterThan(numel(t), 0, 'Time vector should not be empty.');
            testCase.verifyEqual(t0_t1_range(1), 0, 'AbsTol', 1e-9, 'File should start at t=0.');
        end

        function testFormatReadScaled(testCase)
            %TESTFORMATREADSCALED Verify read returns volts when scale is true.
            [data_scaled, ~, ~] = ndr.format.neuropixelsGLX.read(...
                testCase.BinFilename, 0, 0.001, ...
                'numChans', testCase.NumTotalChans, ...
                'SR', testCase.SR, ...
                'channels', 1:2, ...
                'scale', true);

            testCase.verifyClass(data_scaled, 'double', 'Scaled data should be double.');

            % Compare against manual conversion
            [data_raw, ~, ~] = ndr.format.neuropixelsGLX.read(...
                testCase.BinFilename, 0, 0.001, ...
                'numChans', testCase.NumTotalChans, ...
                'SR', testCase.SR, ...
                'channels', 1:2, ...
                'scale', false);

            info = ndr.format.neuropixelsGLX.header(testCase.MetaFilename);
            expected = ndr.format.neuropixelsGLX.samples2volts(data_raw, info, [1 2]);
            testCase.verifyEqual(data_scaled, expected, 'AbsTol', 1e-15, ...
                'Scaled read should match manual samples2volts conversion.');
        end

        function testFormatReadScaleDefault(testCase)
            %TESTFORMATREADSCALEDEFAULT Verify read defaults to scaled output.
            [data, ~, ~] = ndr.format.neuropixelsGLX.read(...
                testCase.BinFilename, 0, 0.001, ...
                'channels', 1:2);

            testCase.verifyClass(data, 'double', ...
                'Default read should return double (scaled).');
        end

        function testChannelSubsetParsing(testCase)
            %TESTCHANNELSUBSETPARSING Verify channel subset field in header.
            info = ndr.format.neuropixelsGLX.header(testCase.MetaFilename);

            if testCase.NumNeuralChansActual < 384
                % Subset case: should have channels 1:N and 385 (sync mapped to 384+1)
                testCase.verifyGreaterThan(numel(info.saved_chan_list), 0, ...
                    'saved_chan_list should not be empty for subset.');
            else
                % Full case: should have 1:385
                testCase.verifyEqual(numel(info.saved_chan_list), 385, ...
                    'Full recording should have 385 saved channels.');
            end
        end

    end % methods (Test)

end % classdef
