classdef TestIntanRhd < matlab.unittest.TestCase
    % TESTINTANRHD - Unit tests for ndr.reader.intan_rhd

    methods (Test)
        function testSamples2Times(testCase)
            % 1. Setup
            reader = ndr.reader.intan_rhd();
            ndr_path = ndr.fun.ndrpath();
            rhd_file = fullfile(ndr_path, 'example_data', 'example.rhd');

            epochstreams = {rhd_file};
            epoch_select = 1;
            channeltype = 'ai';
            channel = 1;

            % 2. Get expected T0 and T1 from the reader itself
            % This ensures we are testing the internal consistency of the reader
            % and specifically the fix in ndr.reader.base.samples2times/times2samples
            t0t1 = reader.t0_t1(epochstreams, epoch_select);
            t0 = t0t1{1}(1);
            t1 = t0t1{1}(2);
            sr = reader.samplerate(epochstreams, epoch_select, channeltype, channel);

            % 3. Test samples2times
            % Test regular sample
            s = [1, 100, 1000];
            t = reader.samples2times(channeltype, channel, epochstreams, epoch_select, s);

            expected_t = (s - 1) / sr + t0;
            testCase.verifyEqual(t, expected_t, 'AbsTol', 1e-9);

            % Test Inf (should be t1)
            % This triggers the code path: t(g) = t0_t1(2);
            % If the fix is not applied (passing scalar instead of vector), this would fail or error.
            s_inf = Inf;
            t_inf = reader.samples2times(channeltype, channel, epochstreams, epoch_select, s_inf);
            testCase.verifyEqual(t_inf, t1, 'AbsTol', 1e-9);

            % 4. Test times2samples
            % Test regular time
            t_in = [t0, t0 + 0.1];
            s_out = reader.times2samples(channeltype, channel, epochstreams, epoch_select, t_in);

            expected_s = 1 + round((t_in - t0) * sr);
            testCase.verifyEqual(s_out, expected_s, 'AbsTol', 1e-9);

            % Test Inf time
            % In times2samples.m: s(g) = 1+sr*diff(t0_t1);
            t_inf_in = Inf;
            s_inf_out = reader.times2samples(channeltype, channel, epochstreams, epoch_select, t_inf_in);

            expected_s_inf = 1 + sr * (t1 - t0);
            testCase.verifyEqual(s_inf_out, expected_s_inf, 'AbsTol', 1e-9);

        end

        function testReadChannels(testCase)
             % Verify that reading channels works and matches ndr.format.intan output logic
            reader = ndr.reader.intan_rhd();
            ndr_path = ndr.fun.ndrpath();
            rhd_file = fullfile(ndr_path, 'example_data', 'example.rhd');

            epochstreams = {rhd_file};
            epoch_select = 1;
            channeltype = 'ai';
            channel = 1;

            % Read a small chunk
            s0 = 1;
            s1 = 100;

            data = reader.readchannels_epochsamples(channeltype, channel, epochstreams, epoch_select, s0, s1);

            % Verify dimensions
            testCase.verifyEqual(size(data, 1), s1 - s0 + 1);
            testCase.verifyEqual(size(data, 2), 1);

            % We can also compare against direct format read if needed, but the above confirms basic reader function
            % and the primary goal is covering samples2times fix.

            % Verify getting header
            header = ndr.format.intan.read_Intan_RHD2000_header(rhd_file);
            testCase.verifyNotEmpty(header);
        end

        function testChannelNameParsing(testCase)
            % Test parsing of Intan channel names to MFDAQ names

            % Valid cases
            names = {'A-000', 'B-005', 'AUX1', 'AUX2', 'DIN-00'};
            types = {'analog_in', 'analog_in', 'auxiliary_in', 'auxiliary_in', 'digital_in'};
            expected = {'ai1', 'ai6', 'ax1', 'ax2', 'di1'};

            for i = 1:length(names)
                result = ndr.reader.intan_rhd.intanname2mfdaqname([], types{i}, names{i});
                testCase.verifyEqual(result, expected{i}, ...
                    ['Failed to convert ' names{i} ' (' types{i} ') to ' expected{i}]);
            end
        end

        function testChannelStructParsing(testCase)
            % Test parsing using channel struct and chip_channel fallback

            % Case 1: Name parsing fails, use chip_channel
            % Assume 'AUX' name but chip_channel 0 -> 'ax1'
            channel_struct.native_channel_name = 'AUX';
            channel_struct.chip_channel = 0;
            type = 'auxiliary_in';

            result = ndr.reader.intan_rhd.intanname2mfdaqname([], type, channel_struct);
            testCase.verifyEqual(result, 'ax1', 'Failed fallback to chip_channel for AUX');

            % Case 2: Name parsing works, ignore chip_channel (or ensure consistency)
            channel_struct.native_channel_name = 'AUX2';
            channel_struct.chip_channel = 99; % Should be ignored if name parses?
            % My logic uses name first.

            result = ndr.reader.intan_rhd.intanname2mfdaqname([], type, channel_struct);
            testCase.verifyEqual(result, 'ax2', 'Should use name if parseable');

            % Case 3: Struct without chip_channel
            channel_struct2.native_channel_name = 'A-000';
            % no chip_channel field
            result = ndr.reader.intan_rhd.intanname2mfdaqname([], 'analog_in', channel_struct2);
            testCase.verifyEqual(result, 'ai1', 'Should work without chip_channel field');
        end

        function testAuxSampleRate(testCase)
            % Test that samplerate works for auxiliary_in
            reader = ndr.reader.intan_rhd();
            ndr_path = ndr.fun.ndrpath();
            rhd_file = fullfile(ndr_path, 'example_data', 'example.rhd');
            epochstreams = {rhd_file};
            epoch_select = 1;

            % This should not error now
            sr = reader.samplerate(epochstreams, epoch_select, 'auxiliary_in', 1);

            % Check if it returns a valid number (header frequency_parameters are usually populated)
            testCase.verifyNotEmpty(sr);
            testCase.verifyTrue(isnumeric(sr));
        end
    end
end
