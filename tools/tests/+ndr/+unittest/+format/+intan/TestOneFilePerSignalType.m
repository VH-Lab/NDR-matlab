classdef TestOneFilePerSignalType < matlab.unittest.TestCase
    % TestOneFilePerSignalType - Cover the "one file per signal type" reader
    %
    % Exercises ndr.format.intan.read_IntanRHD2000_one_file_per_channel_type
    % with synthetic .dat files: interleaved multi-channel reads, digital
    % packed-word reads, sub-range slicing, and prefix resolution (the
    % Intan/lab filename convention where files carry a common prefix
    % ahead of the signal-type name, e.g. "febc0_u000_000_amplifier.dat").

    properties (Access = private)
        tempDir
        cleanupObj
    end

    methods (TestMethodSetup)
        function makeTempDir(testCase)
            testCase.tempDir = tempname;
            mkdir(testCase.tempDir);
            testCase.cleanupObj = onCleanup(@() rmdir(testCase.tempDir, 's'));
        end
    end

    methods (Access = private)
        function writeDat(testCase, name, values, precision)
            fid = fopen(fullfile(testCase.tempDir, name), 'wb', 'ieee-le');
            testCase.assertNotEqual(fid, -1, ['Could not open ' name ' for writing.']);
            fwrite(fid, values, precision);
            fclose(fid);
        end
    end

    methods (Test)
        function testReadAmplifierInterleaved(testCase)
            % 3 channels, 5 samples, int16, interleaved sample-by-sample.
            num_channels = 3;
            num_samples = 5;
            ch1 = int16([ 100  200  300  400  500]);
            ch2 = int16([-100 -200 -300 -400 -500]);
            ch3 = int16([   1    2    3    4    5]);
            interleaved = int16(zeros(1, num_channels * num_samples));
            interleaved(1:num_channels:end) = ch1;
            interleaved(2:num_channels:end) = ch2;
            interleaved(3:num_channels:end) = ch3;
            testCase.writeDat('amplifier.dat', interleaved, 'int16');

            got1 = ndr.format.intan.read_IntanRHD2000_one_file_per_channel_type( ...
                testCase.tempDir, 2, 1, num_channels, 1, num_samples);
            got2 = ndr.format.intan.read_IntanRHD2000_one_file_per_channel_type( ...
                testCase.tempDir, 2, 2, num_channels, 1, num_samples);
            got3 = ndr.format.intan.read_IntanRHD2000_one_file_per_channel_type( ...
                testCase.tempDir, 2, 3, num_channels, 1, num_samples);

            testCase.verifyEqual(double(got1(:)'), double(ch1));
            testCase.verifyEqual(double(got2(:)'), double(ch2));
            testCase.verifyEqual(double(got3(:)'), double(ch3));
        end

        function testAuxiliaryFilename(testCase)
            % Regression: earlier code looked for 'auxin.dat'. Intan's
            % actual filename is 'auxiliary.dat'; verify that name works.
            num_channels = 2;
            num_samples = 4;
            interleaved = uint16(zeros(1, num_channels * num_samples));
            interleaved(1:2:end) = uint16([10 20 30 40]);
            interleaved(2:2:end) = uint16([1000 2000 3000 4000]);
            testCase.writeDat('auxiliary.dat', interleaved, 'uint16');

            got1 = ndr.format.intan.read_IntanRHD2000_one_file_per_channel_type( ...
                testCase.tempDir, 3, 1, num_channels, 1, num_samples);
            got2 = ndr.format.intan.read_IntanRHD2000_one_file_per_channel_type( ...
                testCase.tempDir, 3, 2, num_channels, 1, num_samples);

            testCase.verifyEqual(double(got1(:)'), [10 20 30 40]);
            testCase.verifyEqual(double(got2(:)'), [1000 2000 3000 4000]);
        end

        function testTimeChannel(testCase)
            times = int32([0 1 2 3 4 5 6 7 8 9]);
            testCase.writeDat('time.dat', times, 'int32');

            got = ndr.format.intan.read_IntanRHD2000_one_file_per_channel_type( ...
                testCase.tempDir, 1, 1, 1, 1, numel(times));
            testCase.verifyEqual(double(got(:)'), double(times));
        end

        function testDigitalReturnsPackedWord(testCase)
            % Digital in/out is a single packed 16-bit word per sample.
            % Verify the helper returns the raw word for both channel types.
            words = uint16([0 1 2 4 8 16 32 hex2dec('FFFF')]);
            testCase.writeDat('digitalin.dat', words, 'uint16');

            got = ndr.format.intan.read_IntanRHD2000_one_file_per_channel_type( ...
                testCase.tempDir, 7, 1, 1, 1, numel(words));
            testCase.verifyEqual(double(got(:)'), double(words));

            testCase.writeDat('digitalout.dat', words, 'uint16');
            got = ndr.format.intan.read_IntanRHD2000_one_file_per_channel_type( ...
                testCase.tempDir, 8, 1, 1, 1, numel(words));
            testCase.verifyEqual(double(got(:)'), double(words));
        end

        function testSubRangeSlicing(testCase)
            num_channels = 2;
            num_samples = 8;
            ch1 = int16([10 20 30 40 50 60 70 80]);
            ch2 = int16([11 22 33 44 55 66 77 88]);
            interleaved = int16(zeros(1, num_channels * num_samples));
            interleaved(1:2:end) = ch1;
            interleaved(2:2:end) = ch2;
            testCase.writeDat('amplifier.dat', interleaved, 'int16');

            got = ndr.format.intan.read_IntanRHD2000_one_file_per_channel_type( ...
                testCase.tempDir, 2, 2, num_channels, 3, 6);
            testCase.verifyEqual(double(got(:)'), double(ch2(3:6)));
        end

        function testPrefixedFilename(testCase)
            % Intan appends a timestamp prefix; some labs prepend their own
            % (e.g., "febc0_u000_000_"). The reader should resolve either.
            num_channels = 2;
            num_samples = 3;
            interleaved = int16(zeros(1, num_channels * num_samples));
            interleaved(1:2:end) = int16([7 8 9]);
            interleaved(2:2:end) = int16([70 80 90]);
            testCase.writeDat('febc0_u000_000_amplifier.dat', interleaved, 'int16');

            got1 = ndr.format.intan.read_IntanRHD2000_one_file_per_channel_type( ...
                testCase.tempDir, 2, 1, num_channels, 1, num_samples);
            got2 = ndr.format.intan.read_IntanRHD2000_one_file_per_channel_type( ...
                testCase.tempDir, 2, 2, num_channels, 1, num_samples);

            testCase.verifyEqual(double(got1(:)'), [7 8 9]);
            testCase.verifyEqual(double(got2(:)'), [70 80 90]);
        end

        function testMissingFileErrors(testCase)
            % Empty directory: helper must raise (rather than return junk).
            testCase.verifyError( ...
                @() ndr.format.intan.read_IntanRHD2000_one_file_per_channel_type( ...
                    testCase.tempDir, 2, 1, 1, 1, 1), ...
                ?MException);
        end

        function testReaderDetectsDirectoryFromPrefixedInfo(testCase)
            % ndr.reader.intan_rhd.filenamefromepochfiles should treat a
            % <prefix>_info.rhd paired with a *time.dat sibling as a
            % directory-mode epoch, matching how KJNielsen-style Intan
            % recordings put their per-signal-type files on disk.
            reader = ndr.reader.intan_rhd();

            info_path = fullfile(testCase.tempDir, 'febc0_u000_000_info.rhd');
            time_path = fullfile(testCase.tempDir, 'febc0_u000_000_time.dat');
            fclose(fopen(info_path, 'w'));
            fclose(fopen(time_path, 'w'));

            [~, ~, isdirectory, ~] = reader.filenamefromepochfiles({info_path, time_path});
            testCase.verifyEqual(isdirectory, 1);

            % Bare info.rhd + bare time.dat still count.
            info_bare = fullfile(testCase.tempDir, 'info.rhd');
            time_bare = fullfile(testCase.tempDir, 'time.dat');
            fclose(fopen(info_bare, 'w'));
            fclose(fopen(time_bare, 'w'));
            [~, ~, isdirectory_bare, ~] = reader.filenamefromepochfiles({info_bare, time_bare});
            testCase.verifyEqual(isdirectory_bare, 1);
        end
    end
end
