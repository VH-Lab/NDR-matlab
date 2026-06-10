classdef TestPrairieView < matlab.unittest.TestCase
    %TESTPRAIRIEVIEW Unit tests for the legacy Prairie View reader.
    %
    %   ndr.reader.prairieview reads a legacy Prairie recording: a directory
    %   of one-TIFF-per-frame plus a '*_Main.pcf' config whose
    %   '[Image TimeStamp (us)]' section holds per-frame timestamps. This test
    %   synthesizes such a recording (single-frame TIFFs + a hand-written .pcf)
    %   and checks geometry, frame round-trip (inherited from tiffstack), and
    %   that timestamps come from the config in seconds. No external
    %   dependencies are required.

    properties (Constant)
        Y = 9;   % image height  (Lines per frame)
        X = 7;   % image width   (Pixels per line)
        T = 5;   % number of frames / images
    end

    properties (SetAccess=protected)
        Reader
        TempDir char
        DirEpoch char       % the recording directory
        ConfigFile char     % the *_Main.pcf path
        Truth               % Y x X x 1 x 1 x T ground-truth stack
        TimesUs double      % per-frame timestamps written into the .pcf (microseconds)
        MultiDir char       % a 2-channel recording directory
        MultiTruth          % Y x X x 2 x 1 x T ground-truth (channels on C axis)
        MultiTimesUs double % per-timepoint timestamps for the multichannel recording
        MultiC double       % number of channels in the multichannel recording
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            testCase.TempDir = fullfile(tempdir, ['ndr_pv_test_' char(java.util.UUID.randomUUID)]);
            mkdir(testCase.TempDir);
            testCase.DirEpoch = fullfile(testCase.TempDir,'Recording-001');
            mkdir(testCase.DirEpoch);

            testCase.Reader = ndr.reader('prairieview');
            testCase.assertClass(testCase.Reader, 'ndr.reader', 'Reader initialization failed.');

            Yl = testCase.Y; Xl = testCase.X; Tl = testCase.T;
            truth = zeros(Yl, Xl, 1, 1, Tl, 'uint16');
            for i=1:Tl
                truth(:,:,1,1,i) = uint16( reshape(1:(Yl*Xl), Yl, Xl) + (i-1)*100 );
            end
            testCase.Truth = truth;

            % one TIFF per frame, named so lexical order is acquisition order
            for i=1:Tl
                fn = fullfile(testCase.DirEpoch, sprintf('Recording_Cycle001_Ch2_%06d.tif', i));
                ndr.unittest.reader.TestPrairieView.writeTiff(fn, truth(:,:,1,1,i));
            end

            % irregular per-frame timestamps (microseconds) to prove they come
            % from the config verbatim (not a uniform frame period)
            testCase.TimesUs = [0 90000 250000 260000 600000];
            testCase.ConfigFile = fullfile(testCase.DirEpoch,'Recording_Main.pcf');
            ndr.unittest.reader.TestPrairieView.writePcf(testCase.ConfigFile, ...
                Yl, Xl, Tl, testCase.TimesUs);

            % ---- a 2-channel recording -----------------------------------
            testCase.MultiC = 2;
            testCase.MultiDir = fullfile(testCase.TempDir,'Recording-002');
            mkdir(testCase.MultiDir);
            mtruth = zeros(Yl, Xl, testCase.MultiC, 1, Tl, 'uint16');
            for c=1:testCase.MultiC
                for i=1:Tl
                    % distinct content per (channel,timepoint)
                    mtruth(:,:,c,1,i) = uint16( reshape(1:(Yl*Xl), Yl, Xl) + (i-1)*100 + c*10000 );
                    fn = fullfile(testCase.MultiDir, ...
                        sprintf('Rec_Cycle001_Ch%d_%06d.tif', c, i));
                    ndr.unittest.reader.TestPrairieView.writeTiff(fn, mtruth(:,:,c,1,i));
                end
            end
            testCase.MultiTruth = mtruth;
            testCase.MultiTimesUs = [0 100000 250000 270000 500000];
            ndr.unittest.reader.TestPrairieView.writePcf( ...
                fullfile(testCase.MultiDir,'Rec_Main.pcf'), Yl, Xl, Tl, testCase.MultiTimesUs);
        end
    end

    methods (TestClassTeardown)
        function teardownOnce(testCase)
            if ~isempty(testCase.TempDir) && isfolder(testCase.TempDir)
                try
                    rmdir(testCase.TempDir, 's');
                catch ME
                    warning('Could not remove temporary directory %s: %s', testCase.TempDir, ME.message);
                end
            end
        end
    end

    methods (Test)

        function testConfigParsing(testCase)
            v = ndr.format.prairieview.readconfig(testCase.DirEpoch);
            testCase.verifyFalse(v.is_xml, 'Legacy .pcf should not be flagged as XML.');
            testCase.verifyEqual(v.Main.Total_images, testCase.T, 'Total_images mismatch.');
            testCase.verifyEqual(v.Main.Lines_per_frame, testCase.Y, 'Lines_per_frame mismatch.');
            testCase.verifyEqual(v.Main.Pixels_per_line, testCase.X, 'Pixels_per_line mismatch.');
            testCase.verifyEqual(v.Image_TimeStamp__us_(:)', testCase.TimesUs, ...
                'Parsed image timestamps mismatch.');
        end

        function testConfigFilenameDiscovery(testCase)
            % both a directory and a file in it must resolve to the .pcf
            fromDir = ndr.format.prairieview.configfilename(testCase.DirEpoch);
            testCase.verifyEqual(fromDir, testCase.ConfigFile, ...
                'configfilename did not find the .pcf from the directory.');
        end

        function testGeometry(testCase)
            ef = {testCase.DirEpoch};
            testCase.verifyEqual(testCase.Reader.numframes(ef,1), testCase.T, 'numframes mismatch.');
            sz = testCase.Reader.framesize(ef,1);
            testCase.verifyEqual(sz, [testCase.Y testCase.X 1 1 testCase.T], 'framesize mismatch.');
            testCase.verifyEqual(testCase.Reader.datatype(ef,1), 'uint16', 'datatype mismatch.');
        end

        function testFramesRoundTrip(testCase)
            ef = {testCase.DirEpoch};
            frames = testCase.Reader.readframes(ef,1);
            testCase.verifyEqual(frames, testCase.Truth, 'Frames did not round-trip / order correctly.');
        end

        function testTimestampsFromConfig(testCase)
            ef = {testCase.DirEpoch};
            ec = testCase.Reader.epochclock(ef,1);
            testCase.verifyEqual(ec{1}.type, 'dev_local_time', ...
                'Epoch with config timestamps should be dev_local_time.');
            ft = testCase.Reader.frametimes(ef,1);
            testCase.verifyEqual(ft(:)', testCase.TimesUs/1e6, 'AbsTol', 1e-12, ...
                'Frame times should be the config timestamps in seconds.');
            t0t1 = testCase.Reader.t0_t1(ef,1);
            testCase.verifyEqual(t0t1{1}, [testCase.TimesUs(1) testCase.TimesUs(end)]/1e6, ...
                'AbsTol', 1e-12, 't0_t1 mismatch.');
            % subset request
            ftsub = testCase.Reader.frametimes(ef,1,[2 4]);
            testCase.verifyEqual(ftsub(:)', testCase.TimesUs([2 4])/1e6, 'AbsTol', 1e-12, ...
                'Frame-time subset mismatch.');
        end

        function testAnchorOnConfigFile(testCase)
            % passing the .pcf itself as the epoch must behave like the directory
            byCfg = testCase.Reader.readframes({testCase.ConfigFile},1);
            byDir = testCase.Reader.readframes({testCase.DirEpoch},1);
            testCase.verifyEqual(byCfg, byDir, 'Config-file epoch and directory epoch disagree on frames.');
            ftCfg = testCase.Reader.frametimes({testCase.ConfigFile},1);
            testCase.verifyEqual(ftCfg(:)', testCase.TimesUs/1e6, 'AbsTol', 1e-12, ...
                'Config-file epoch did not pick up timestamps.');
        end

        function testMultiChannelGeometry(testCase)
            ef = {testCase.MultiDir};
            % a frame is a timepoint; channels do not multiply the frame count
            testCase.verifyEqual(testCase.Reader.numframes(ef,1), testCase.T, ...
                'Multi-channel numframes should equal the number of timepoints.');
            sz = testCase.Reader.framesize(ef,1);
            testCase.verifyEqual(sz, [testCase.Y testCase.X testCase.MultiC 1 testCase.T], ...
                'Multi-channel framesize should carry C on the channel axis.');
        end

        function testMultiChannelFramesRoundTrip(testCase)
            ef = {testCase.MultiDir};
            frames = testCase.Reader.readframes(ef,1);
            testCase.verifyEqual(frames, testCase.MultiTruth, ...
                'Multi-channel frames did not round-trip with channels on the C axis.');
            % a single timepoint carries both channels
            one = testCase.Reader.readframes(ef,1,3);
            testCase.verifyEqual(one, testCase.MultiTruth(:,:,:,:,3), ...
                'Single-timepoint multi-channel read mismatch.');
        end

        function testMultiChannelTimesPerTimepoint(testCase)
            ef = {testCase.MultiDir};
            ft = testCase.Reader.frametimes(ef,1);
            testCase.verifyEqual(numel(ft), testCase.T, ...
                'There should be one timestamp per timepoint, not per channel.');
            testCase.verifyEqual(ft(:)', testCase.MultiTimesUs/1e6, 'AbsTol', 1e-12, ...
                'Multi-channel frame times should be the config timestamps in seconds.');
            ec = testCase.Reader.epochclock(ef,1);
            testCase.verifyEqual(ec{1}.type, 'dev_local_time', ...
                'Multi-channel epoch with config times should be dev_local_time.');
        end

    end % methods (Test)

    methods (Static)
        function writeTiff(filename, img)
            t = Tiff(filename,'w');
            c = onCleanup(@() t.close());
            tags.ImageLength = size(img,1);
            tags.ImageWidth = size(img,2);
            tags.Photometric = Tiff.Photometric.MinIsBlack;
            tags.BitsPerSample = 16;
            tags.SamplesPerPixel = 1;
            tags.SampleFormat = Tiff.SampleFormat.UInt;
            tags.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
            tags.Compression = Tiff.Compression.None;
            t.setTag(tags);
            t.write(img);
        end

        function writePcf(filename, Y, X, T, timesUs)
            % Write a minimal legacy Prairie '.pcf': a [Main] section (read
            % first, so Total images is known) and an [Image TimeStamp (us)]
            % section with one '<label>=<us>' line per image.
            fid = fopen(filename,'w');
            c = onCleanup(@() fclose(fid));
            fprintf(fid,'[Main]\n');
            fprintf(fid,'Total images = %d\n', T);
            fprintf(fid,'Lines per frame = %d\n', Y);
            fprintf(fid,'Pixels per line = %d\n', X);
            fprintf(fid,'Frame period (us) = %d\n', 250000);
            fprintf(fid,'\n');
            fprintf(fid,'[Image TimeStamp (us)]\n');
            for i=1:T
                fprintf(fid,'%d=%g\n', i, timesUs(i));
            end
        end
    end % methods (Static)

end % classdef
