classdef TestNeuropixelsGLX_nidq < matlab.unittest.TestCase
%TESTNEUROPIXELSGLX_NIDQ Unit tests for NI-DAQ stream support in neuropixelsGLX.
%
%   Tests header parsing, voltage scaling, and read for NIDQ-format files
%   with niMNGain, niMAGain, and snsMnMaXaDw fields.
%
%   Example:
%       results = runtests('ndr.unittest.reader.TestNeuropixelsGLX_nidq');

    properties (Constant)
        SR = 25000;
        NumSamples = 500;
        NumMN = 8;       % multiplexed neural
        NumMA = 2;       % multiplexed analog
        NumXA = 1;       % non-multiplexed analog
        NumDW = 1;       % digital words
        MNGain = 200;
        MAGain = 100;
        VMax = 5.0;
        MaxInt = 32768;
    end

    properties (SetAccess=protected)
        TempDir char = ''
        MetaFilename char = ''
        BinFilename char = ''
        NumTotalChans double = NaN
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            testCase.TempDir = fullfile(tempdir, ['ndr_nidq_test_' char(java.util.UUID.randomUUID)]);
            mkdir(testCase.TempDir);

            nMN = testCase.NumMN;
            nMA = testCase.NumMA;
            nXA = testCase.NumXA;
            nDW = testCase.NumDW;
            testCase.NumTotalChans = nMN + nMA + nXA + nDW;

            testCase.MetaFilename = fullfile(testCase.TempDir, 'test_nidq.nidq.meta');
            testCase.BinFilename  = fullfile(testCase.TempDir, 'test_nidq.nidq.bin');

            % Generate test data
            nSamples = testCase.NumSamples;
            nTotal = testCase.NumTotalChans;
            data = zeros(nSamples, nTotal, 'int16');
            for c = 1:nTotal
                data(:, c) = int16((c-1)*10 + (1:nSamples))';
            end

            % Write binary file
            fid = fopen(testCase.BinFilename, 'w', 'ieee-le');
            interleaved = reshape(data', 1, []);
            fwrite(fid, interleaved, 'int16');
            fclose(fid);

            % Write meta file
            fileSizeBytes = nSamples * nTotal * 2;
            fileTimeSecs = nSamples / testCase.SR;
            fid = fopen(testCase.MetaFilename, 'w');
            fprintf(fid, 'niSampRate=%g\n', testCase.SR);
            fprintf(fid, 'nSavedChans=%d\n', nTotal);
            fprintf(fid, 'snsMnMaXaDw=%d,%d,%d,%d\n', nMN, nMA, nXA, nDW);
            fprintf(fid, 'snsSaveChanSubset=all\n');
            fprintf(fid, 'fileSizeBytes=%d\n', fileSizeBytes);
            fprintf(fid, 'fileTimeSecs=%.6f\n', fileTimeSecs);
            fprintf(fid, 'niAiRangeMax=%.1f\n', testCase.VMax);
            fprintf(fid, 'niAiRangeMin=-%.1f\n', testCase.VMax);
            fprintf(fid, 'niMaxInt=%d\n', testCase.MaxInt);
            fprintf(fid, 'niMNGain=%d\n', testCase.MNGain);
            fprintf(fid, 'niMAGain=%d\n', testCase.MAGain);
            fclose(fid);
        end
    end

    methods (TestClassTeardown)
        function teardownOnce(testCase)
            if ~isempty(testCase.TempDir) && isfolder(testCase.TempDir)
                try
                    rmdir(testCase.TempDir, 's');
                catch
                end
            end
        end
    end

    methods (Test)

        function testHeaderNidq(testCase)
            %TESTHEADERNIDQ Verify header parses NIDQ fields correctly.
            info = ndr.format.neuropixelsGLX.header(testCase.MetaFilename);

            testCase.verifyEqual(info.stream_type, 'nidq');
            testCase.verifyEqual(info.sample_rate, testCase.SR);
            testCase.verifyEqual(info.n_saved_chans, testCase.NumTotalChans);
            testCase.verifyEqual(info.n_mn_chans, testCase.NumMN);
            testCase.verifyEqual(info.n_ma_chans, testCase.NumMA);
            testCase.verifyEqual(info.n_xa_chans, testCase.NumXA);
            testCase.verifyEqual(info.n_dw_chans, testCase.NumDW);
            testCase.verifyEqual(info.voltage_range, [-testCase.VMax testCase.VMax]);
            testCase.verifyEqual(info.max_int, testCase.MaxInt);
            testCase.verifyEqual(info.ni_mn_gain, testCase.MNGain);
            testCase.verifyEqual(info.ni_ma_gain, testCase.MAGain);
        end

        function testSamples2VoltsNidqMN(testCase)
            %TESTSAMPLES2VOLTSNIDQMN Verify scaling for MN channels.
            info = ndr.format.neuropixelsGLX.header(testCase.MetaFilename);
            raw = int16([1000; -1000; 0]);
            volts = ndr.format.neuropixelsGLX.samples2volts(raw, info, 1);

            expected = double(raw) * testCase.VMax / (testCase.MaxInt * testCase.MNGain);
            testCase.verifyEqual(volts, expected, 'AbsTol', 1e-15, ...
                'MN channel scaling incorrect.');
        end

        function testSamples2VoltsNidqMA(testCase)
            %TESTSAMPLES2VOLTSNIDQMA Verify scaling for MA channels.
            info = ndr.format.neuropixelsGLX.header(testCase.MetaFilename);
            raw = int16([500; -500]);
            ma_chan = testCase.NumMN + 1; % first MA channel
            volts = ndr.format.neuropixelsGLX.samples2volts(raw, info, ma_chan);

            expected = double(raw) * testCase.VMax / (testCase.MaxInt * testCase.MAGain);
            testCase.verifyEqual(volts, expected, 'AbsTol', 1e-15, ...
                'MA channel scaling incorrect.');
        end

        function testSamples2VoltsNidqMixed(testCase)
            %TESTSAMPLES2VOLTSNIDQMIXED Verify mixed MN+MA channel scaling.
            info = ndr.format.neuropixelsGLX.header(testCase.MetaFilename);
            raw = int16([1000 500; -1000 -500]);
            channels = [1, testCase.NumMN + 1]; % one MN, one MA
            volts = ndr.format.neuropixelsGLX.samples2volts(raw, info, channels);

            scale_mn = testCase.VMax / (testCase.MaxInt * testCase.MNGain);
            scale_ma = testCase.VMax / (testCase.MaxInt * testCase.MAGain);
            expected = [double(raw(:,1)) * scale_mn, double(raw(:,2)) * scale_ma];
            testCase.verifyEqual(volts, expected, 'AbsTol', 1e-15, ...
                'Mixed MN+MA scaling incorrect.');
        end

        function testReadNidqScaled(testCase)
            %TESTREADNIDQSCALED Verify read with default scaling for NIDQ.
            [data, t, t0_t1] = ndr.format.neuropixelsGLX.read(...
                testCase.BinFilename, 0, 0.001);

            testCase.verifyClass(data, 'double', 'Scaled NIDQ data should be double.');
            testCase.verifyGreaterThan(numel(t), 0);
            testCase.verifyEqual(t0_t1(1), 0, 'AbsTol', 1e-9);
        end

        function testReadNidqUnscaled(testCase)
            %TESTREADNIDQUNSCALED Verify read with scale=false for NIDQ.
            [data, ~, ~] = ndr.format.neuropixelsGLX.read(...
                testCase.BinFilename, 0, 0.001, 'scale', false);

            testCase.verifyClass(data, 'int16', 'Unscaled NIDQ data should be int16.');
        end

        function testReadNidqScaledMatchesManual(testCase)
            %TESTREADNIDQSCALEDMATCHESMANUAL Verify scaled read matches manual conversion.
            channels = [1, testCase.NumMN + 1]; % MN and MA channel

            [data_scaled, ~, ~] = ndr.format.neuropixelsGLX.read(...
                testCase.BinFilename, 0, 0.01, 'channels', channels);

            [data_raw, ~, ~] = ndr.format.neuropixelsGLX.read(...
                testCase.BinFilename, 0, 0.01, 'channels', channels, 'scale', false);

            info = ndr.format.neuropixelsGLX.header(testCase.MetaFilename);
            expected = ndr.format.neuropixelsGLX.samples2volts(data_raw, info, channels);

            testCase.verifyEqual(data_scaled, expected, 'AbsTol', 1e-15, ...
                'Scaled read should match manual samples2volts for NIDQ.');
        end

    end

end
