classdef readerTest_whitematter < matlab.unittest.TestCase
    %READERTEST_WHITEMATTER Unit tests for the ndr.reader.whitematter class
    %   Tests the functionality of the WhiteMatter LLC reader by creating
    %   temporary test files and verifying the output of various reader methods.

    properties (Constant)
        SR = 20000; % Sampling rate for test files (Hz)
        NumSamples = 999; % Number of samples per channel
        HeaderBytes = 8;  % Standard header size for WM files
        ByteOrder = 'ieee-le'; % Default byte order
        DataType = 'int16'; % Data type for samples
    end

    properties (ClassSetupParameter)
        % Define different channel counts to test
        NumChannelsToTest = {3, 7, 10};
    end

    properties (SetAccess=protected)
        % Separated properties instead of struct array
        TestFilename char = ''  % Store the full path to the test file
        TestNumChannels double = NaN % Store the number of channels for the test file
        TestHeaderInfo struct = struct() % Store the parsed header info
        Reader % The reader object instance (type assigned in setupOnce)
        TempDir char % Temporary directory for test files
    end

    methods (TestClassSetup)
        % Runs once before all tests in the class
        function setupOnce(testCase, NumChannelsToTest)
            disp('Setting up test files for ndr.reader.whitematter...');

            % Create a unique temporary directory for this test run
            testCase.TempDir = fullfile(tempdir, ['ndr_wm_test_' char(java.util.UUID.randomUUID)]);
            if ~isfolder(testCase.TempDir)
                mkdir(testCase.TempDir);
            end
            disp(['Temporary directory: ' testCase.TempDir]);

            % Initialize the reader ONCE here
            testCase.Reader = ndr.reader('whitematter');
            testCase.assertClass(testCase.Reader, 'ndr.reader', 'Reader initialization failed.');

            % --- Create Test File ---
            numChans = NumChannelsToTest; % Get the specific channel count for this setup
            testCase.TestNumChannels = numChans; % Assign to the new property

            % Generate Filename based on parameters
            nowTime = datetime('now', 'Format', 'yyyy_MM_dd__HH_mm_ss');
            durationSec = double(testCase.NumSamples) / testCase.SR;
            durationMin = floor(durationSec / 60);
            durationSecRem = round(rem(durationSec, 60));
            devType = ['testdev_' num2str(numChans) 'ch']; % Example device type

            % Using 'mm' for month and 'MM' for minute based on datestr documentation
            dateStringForFilename = datestr(nowTime, 'yyyy_mm_dd__HH_MM_ss');

            baseFilename = sprintf('HSW_%s__%02dmin_%02dsec__%s_%dsps.bin', ...
                                   dateStringForFilename, ...
                                   durationMin, durationSecRem, ...
                                   devType, testCase.SR);
            testCase.TestFilename = fullfile(testCase.TempDir, baseFilename); % Assign to the new property

            % Generate Data
            nSamples = testCase.NumSamples;
            data = zeros(nSamples, numChans, testCase.DataType);
            for c = 1:numChans
                start_val = (c-1) * 1000 + 1;
                end_val = start_val + nSamples - 1;
                data(:, c) = int16(start_val:end_val)';
            end

            % Interleave data (MATLAB stores column-major, file needs row-major samples)
            % Reshape to Samples x Channels, then transpose to Channels x Samples, then linearize
            interleavedData = reshape(data', 1, []);

            % Write File
            fid = fopen(testCase.TestFilename, 'w', testCase.ByteOrder);
            testCase.assertNotEqual(fid, -1, ['Could not open test file for writing: ' testCase.TestFilename]);

            % Write dummy header
            fwrite(fid, zeros(1, testCase.HeaderBytes), 'uint8');

            % Write interleaved data
            count = fwrite(fid, interleavedData, testCase.DataType);
            fclose(fid);

            testCase.assertEqual(count, numel(interleavedData), 'Incorrect number of samples written to test file.');

            % Read header info using the format function
            testCase.TestHeaderInfo = ndr.format.whitematter.header(testCase.TestFilename); % Assign to the new property

            disp(['Created test file: ' testCase.TestFilename ' with ' num2str(numChans) ' channels.']);
            disp('Setup complete.');
        end
    end

    methods (TestClassTeardown)
        % Runs once after all tests in the class
        function teardownOnce(testCase)
            disp('Cleaning up test files...');
            if ~isempty(testCase.TempDir) && isfolder(testCase.TempDir)
                try
                    rmdir(testCase.TempDir, 's'); % Remove temporary directory and its contents
                    disp(['Removed temporary directory: ' testCase.TempDir]);
                catch ME
                    warning('Could not remove temporary directory %s: %s', testCase.TempDir, ME.message);
                end
            end
            disp('Teardown complete.');
        end
    end

    methods (TestMethodSetup)
        % Runs before each test method (can be used if needed)
        function setup(testCase)
            % Reader should exist from setupOnce, just verify essentials
            testCase.assertNotEmpty(testCase.Reader, 'Reader object is empty in test setup.');
            testCase.assertClass(testCase.Reader, 'ndr.reader', 'Reader object type mismatch in test setup.');
            % Verify new properties are populated
            testCase.assertNotEmpty(testCase.TestFilename, 'TestFilename is empty in test setup.');
            testCase.assertFalse(isnan(testCase.TestNumChannels), 'TestNumChannels is NaN in test setup.');
            testCase.assertFalse(isempty(fieldnames(testCase.TestHeaderInfo)), 'TestHeaderInfo is empty in test setup.');
        end
    end

    % --- Test Methods ---

    methods (Test)
        function testGetChannelEpoch(testCase)
            % Test the getchannelsepoch method
            channels = testCase.Reader.getchannelsepoch({testCase.TestFilename}); % Use new property

            expectedNumTotalChannels = testCase.TestNumChannels + 1; % data channels + time channel
            testCase.verifyNumElements(channels, expectedNumTotalChannels, ...
                'Incorrect number of channels returned by getchannelsepoch.');

            % Check time channel
            testCase.verifyEqual(channels(1).name, 't1', 'First channel should be time channel t1.');
            testCase.verifyEqual(channels(1).type, 'time', 'Type of first channel should be time.');

            % Check data channels
            for i = 1:testCase.TestNumChannels
                expectedName = ['ai' int2str(i)];
                testCase.verifyEqual(channels(i+1).name, expectedName, ...
                    ['Incorrect name for data channel ' num2str(i)]);
                testCase.verifyEqual(channels(i+1).type, 'analog_in', ...
                     ['Incorrect type for data channel ' num2str(i)]);
            end
        end

        function testSampleRate(testCase)
            % Test the samplerate method
            {testCase.TestFilename},
            sr = testCase.Reader.samplerate({testCase.TestFilename}, 1, 'ai', 1:testCase.TestNumChannels) % Use new property
            testCase.verifyEqual(sr, repmat(testCase.SR, size(1:testCase.TestNumChannels)), ...
                'Incorrect sample rate returned for analog channels.');

            sr_time = testCase.Reader.samplerate({testCase.TestFilename}, 1, 'time', 1); % Use new property
             testCase.verifyEqual(sr_time, testCase.SR, ...
                'Incorrect sample rate returned for time channel.');
        end

        function testEpochClock(testCase)
            % Test the epochclock method
            ec = testCase.Reader.epochclock({testCase.TestFilename}, 1); % Use new property
            testCase.verifyNumElements(ec, 1, 'Expected one clock type.');
            testCase.verifyEqual(ec{1}.type, 'dev_local_time', 'Expected clock type dev_local_time.');
        end

        function testT0T1(testCase)
            % Test the t0_t1 method
            t0t1 = testCase.Reader.t0_t1({testCase.TestFilename}, 1); % Use new property

            expected_t0 = 0;
            expected_t1 = (testCase.NumSamples - 1) / testCase.SR; % Time of the last sample

            testCase.verifyNumElements(t0t1, 1, 't0_t1 should return a cell array with one element.');
            testCase.verifySize(t0t1{1}, [1 2], 't0_t1{1} should be a 1x2 vector.');
            testCase.verifyEqual(t0t1{1}(1), expected_t0, 'AbsTol', 1e-9, 'Incorrect t0 returned.');
            testCase.verifyEqual(t0t1{1}(2), expected_t1, 'AbsTol', 1e-9, 'Incorrect t1 returned.');
        end

        function testUnderlyingDatatype(testCase)
            % Test the underlying_datatype method
            % Need at least 2 channels for this specific test case part
            channels_to_test = [1 min(2, testCase.TestNumChannels)]; % Use new property
            [dtype_ai, p_ai, dsize_ai] = testCase.Reader.underlying_datatype(...
                {testCase.TestFilename}, 1, 'ai', channels_to_test); % Use new property
            testCase.verifyEqual(dtype_ai, 'int16', 'Incorrect data type for ai.');
            testCase.verifyEqual(p_ai, repmat([0 1], numel(channels_to_test), 1), 'Incorrect scaling polynomial for ai.');
            testCase.verifyEqual(dsize_ai, 16, 'Incorrect data size for ai.');

            [dtype_t, p_t, dsize_t] = testCase.Reader.underlying_datatype(...
                {testCase.TestFilename}, 1, 'time', 1); % Use new property
            testCase.verifyEqual(dtype_t, 'double', 'Incorrect data type for time.');
            testCase.verifyEqual(p_t, [0 1], 'Incorrect scaling polynomial for time.');
            testCase.verifyEqual(dsize_t, 64, 'Incorrect data size for time.');
        end

        function testReadChannelsEpochSamples_All(testCase)
            % Test reading all channels using readchannels_epochsamples
            numChans = testCase.TestNumChannels; % Use new property
            s0 = 10;
            s1 = 59;
            numSamplesRead = s1 - s0 + 1;

            data = testCase.Reader.readchannels_epochsamples('ai', 1:numChans, ...
                {testCase.TestFilename}, 1, s0, s1); % Use new property

            testCase.verifyClass(data, testCase.DataType, 'Data read should be int16.');
            testCase.verifySize(data, [numSamplesRead, numChans], 'Incorrect size of data read.');

            % Verify data content for a few channels/samples
            for c = 1:numChans
                expected_start_val = int16((c-1) * 1000 + s0);
                expected_end_val = int16((c-1) * 1000 + s1);
                testCase.verifyEqual(data(1, c), expected_start_val, ...
                    ['Incorrect first sample value for channel ' num2str(c)]);
                testCase.verifyEqual(data(end, c), expected_end_val, ...
                     ['Incorrect last sample value for channel ' num2str(c)]);
                testCase.verifyEqual(data(:,c), int16(expected_start_val:expected_end_val)', ...
                     ['Incorrect data sequence for channel ' num2str(c)]);
            end

             % Test reading time
            time = testCase.Reader.readchannels_epochsamples('time', 1, ...
                 {testCase.TestFilename}, 1, s0, s1); % Use new property
            testCase.verifyClass(time, 'double', 'Time read should be double.');
            testCase.verifySize(time, [numSamplesRead, 1], 'Incorrect size of time vector read.');

            expected_t_start = (s0-1)/testCase.SR;
            expected_t_end = (s1-1)/testCase.SR;
            testCase.verifyEqual(time(1), expected_t_start, 'AbsTol', 1e-9, 'Incorrect start time.');
            testCase.verifyEqual(time(end), expected_t_end, 'AbsTol', 1e-9, 'Incorrect end time.');

        end

        function testReadChannelsEpochSamples_Subset(testCase)
            % Test reading a subset of channels using readchannels_epochsamples
            numChans = testCase.TestNumChannels; % Use new property
            channelsToRead = [1, min(3, numChans)]; % Read channels 1 and 3 (or 1 and max if < 3)

            s0 = 100;
            s1 = 149;
            numSamplesRead = s1 - s0 + 1;

            data = testCase.Reader.readchannels_epochsamples('ai', channelsToRead, ...
                {testCase.TestFilename}, 1, s0, s1); % Use new property

            testCase.verifyClass(data, testCase.DataType, 'Data read should be int16.');
            testCase.verifySize(data, [numSamplesRead, numel(channelsToRead)], 'Incorrect size of data read.');

            % Verify data content
            for k = 1:numel(channelsToRead)
                c = channelsToRead(k);
                expected_start_val = int16((c-1) * 1000 + s0);
                expected_end_val = int16((c-1) * 1000 + s1);
                testCase.verifyEqual(data(:,k), int16(expected_start_val:expected_end_val)', ...
                     ['Incorrect data sequence for channel ' num2str(c)]);
            end
        end

        function testReadMethod(testCase)
            % Test reading using the high-level read method
            numChans = testCase.TestNumChannels; % Use new property
            t0 = 0.01; % 10 ms
            t1 = 0.02; % 20 ms

            s0_expected = ndr.time.fun.times2samples(t0, [0 0], testCase.SR);
            s1_expected = ndr.time.fun.times2samples(t1, [0 0], testCase.SR);
            numSamplesExpected = s1_expected - s0_expected + 1;

            channelString = ['ai1-' num2str(numChans)]; % Read all channels

            [data, time] = testCase.Reader.read({testCase.TestFilename}, channelString, 't0', t0, 't1', t1); % Use new property

            testCase.verifyClass(data, testCase.DataType, 'Data read should be int16.');
            testCase.verifySize(data, [numSamplesExpected, numChans], 'Incorrect size of data read via read method.');
            testCase.verifyClass(time, 'double', 'Time read should be double.');
            testCase.verifySize(time, [numSamplesExpected, 1], 'Incorrect size of time vector read via read method.');

            % Verify time vector bounds
            testCase.verifyEqual(time(1), (s0_expected-1)/testCase.SR, 'AbsTol', 1e-9, 'Incorrect start time via read method.');
            testCase.verifyEqual(time(end), (s1_expected-1)/testCase.SR, 'AbsTol', 1e-9, 'Incorrect end time via read method.');

             % Verify data content for first channel
             c = 1;
             expected_start_val = int16((c-1) * 1000 + s0_expected);
             expected_end_val = int16((c-1) * 1000 + s1_expected);
             testCase.verifyEqual(data(:,c), int16(expected_start_val:expected_end_val)', ...
                     ['Incorrect data sequence for channel ' num2str(c) ' via read method.']);

        end

    end % methods (Test)

end % classdef
