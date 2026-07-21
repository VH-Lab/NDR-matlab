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

        % raster-timing parameters written into the modern PVScan XML fixture,
        % exercised by the metadata() tests. FramePeriodSec / ScanLinePeriodSec
        % are in seconds (as PrairieView stores framePeriod / scanLinePeriod);
        % DwellTimeUs is in microseconds (as PrairieView stores dwellTime).
        FramePeriodSec = 1.4819328;
        ScanLinePeriodSec = 6.316e-05;
        DwellTimeUs = 3.6;
        BidirectionalTruth = true;
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
        XmlDir char         % a modern-PVScan-XML 2-channel recording directory
        XmlTruth            % Y x X x 2 x 1 x T ground-truth for the XML recording
        XmlTimesSec double  % per-timepoint absoluteTime values (seconds) in the XML
        XmlC double         % number of channels in the XML recording
        V2Dir char          % a legacy v2.2 '.NET DataSet' XML recording directory
        V2Truth             % Y x X x 2 x 1 x T ground-truth for the v2 recording
        V2TimesMs double    % per-timepoint <Time> values (milliseconds) in the v2 XML
        V2C double          % number of channels in the v2 recording
        CycDir char         % a multi-cycle .pcf recording directory (one epoch = several cycles)
        CycTruth            % Y x X x 1 x 1 x T ground-truth across all cycles
        CycTimesUs double   % per-frame timestamps (us) across all cycles
        CycCounts double    % number of images in each cycle
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

            % ---- a modern-PVScan-XML 2-channel recording -----------------
            % timestamps come from per-frame <Frame absoluteTime="..."> (seconds)
            testCase.XmlC = 2;
            Txml = 3;
            testCase.XmlDir = fullfile(testCase.TempDir,'Recording-XML');
            mkdir(testCase.XmlDir);
            % Real Prairie layout: one frame per <Sequence cycle="N"> (the
            % cycle is the timepoint), filename frame index fixed at 000001,
            % 3-digit cycle, channels as separate Ch1/Ch2 TIFFs.
            xtruth = zeros(Yl, Xl, testCase.XmlC, 1, Txml, 'uint16');
            for c=1:testCase.XmlC
                for i=1:Txml
                    xtruth(:,:,c,1,i) = uint16( reshape(1:(Yl*Xl), Yl, Xl) + (i-1)*100 + c*5000 );
                    fn = fullfile(testCase.XmlDir, ...
                        sprintf('t00004-001_Cycle%03d_CurrentSettings_Ch%d_000001.tif', i, c));
                    ndr.unittest.reader.TestPrairieView.writeTiff(fn, xtruth(:,:,c,1,i));
                end
            end
            testCase.XmlTruth = xtruth;
            % use realistic, irregular absoluteTime values (seconds)
            testCase.XmlTimesSec = [0.329333 2.132962 3.976685];
            ndr.unittest.reader.TestPrairieView.writePVScanXml( ...
                fullfile(testCase.XmlDir,'t00004-001.xml'), Yl, Xl, testCase.XmlTimesSec);

            % ---- a legacy v2.2 '.NET DataSet' XML 2-channel recording -----
            % per-frame <Time> (ms) inside <Dataset_x0020_N> rows, with an
            % embedded <xs:schema> that must be skipped when reading dims
            testCase.V2C = 2;
            Tv2 = 3;
            testCase.V2Dir = fullfile(testCase.TempDir,'Recording-v2');
            mkdir(testCase.V2Dir);
            v2truth = zeros(Yl, Xl, testCase.V2C, 1, Tv2, 'uint16');
            for c=1:testCase.V2C
                for i=1:Tv2
                    v2truth(:,:,c,1,i) = uint16( reshape(1:(Yl*Xl), Yl, Xl) + (i-1)*100 + c*3000 );
                    fn = fullfile(testCase.V2Dir, ...
                        sprintf('t00001-001_Cycle%03d_Ch%d_000001.tif', i, c));
                    ndr.unittest.reader.TestPrairieView.writeTiff(fn, v2truth(:,:,c,1,i));
                end
            end
            testCase.V2Truth = v2truth;
            testCase.V2TimesMs = [0 1468.75 2875];
            ndr.unittest.reader.TestPrairieView.writeV2Xml( ...
                fullfile(testCase.V2Dir,'t00001-001.xml'), Yl, Xl, testCase.V2TimesMs);

            % ---- a multi-cycle .pcf recording (one epoch = 3 cycles) ------
            % mirrors a real Prairie run: [Main] Total images, per-[Cycle N]
            % image counts, and an [Image TimeStamp (us)] list spanning all
            % cycles. Frames are named with the cycle and a per-cycle frame
            % index that resets each cycle; the global order is cycle-then-frame.
            testCase.CycCounts = [1 4 1];   % 6 frames total, single channel
            Tcyc = sum(testCase.CycCounts);
            testCase.CycDir = fullfile(testCase.TempDir,'t00012-001');
            mkdir(testCase.CycDir);
            cyctruth = zeros(Yl, Xl, 1, 1, Tcyc, 'uint16');
            tp = 0;
            for cyc=1:numel(testCase.CycCounts)
                for fr=1:testCase.CycCounts(cyc)
                    tp = tp + 1;
                    cyctruth(:,:,1,1,tp) = uint16( reshape(1:(Yl*Xl), Yl, Xl) + (tp-1)*100 );
                    fn = fullfile(testCase.CycDir, ...
                        sprintf('t00012-001_Cycle%03d_CurrentSettings_Ch1_%06d.tif', cyc, fr));
                    ndr.unittest.reader.TestPrairieView.writeTiff(fn, cyctruth(:,:,1,1,tp));
                end
            end
            testCase.CycTruth = cyctruth;
            testCase.CycTimesUs = (0:Tcyc-1) * 1486848;   % us, ~real frame period
            ndr.unittest.reader.TestPrairieView.writeMultiCyclePcf( ...
                fullfile(testCase.CycDir,'t00012-001_Main.pcf'), Yl, Xl, ...
                testCase.CycCounts, testCase.CycTimesUs);
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

        function testXmlConfigParsing(testCase)
            v = ndr.format.prairieview.readconfig(testCase.XmlDir);
            testCase.verifyTrue(v.is_xml, 'XML config should set is_xml=true.');
            testCase.verifyEqual(v.Main.Lines_per_frame, testCase.Y, 'XML Lines_per_frame mismatch.');
            testCase.verifyEqual(v.Main.Pixels_per_line, testCase.X, 'XML Pixels_per_line mismatch.');
            testCase.verifyEqual(v.Image_TimeStamp__us_(:)', testCase.XmlTimesSec*1e6, ...
                'AbsTol', 1e-3, 'XML per-frame timestamps (us) mismatch.');
        end

        function testXmlGeometryAndFrames(testCase)
            ef = {testCase.XmlDir};
            testCase.verifyEqual(testCase.Reader.numframes(ef,1), numel(testCase.XmlTimesSec), ...
                'XML numframes should equal the number of timepoints.');
            sz = testCase.Reader.framesize(ef,1);
            testCase.verifyEqual(sz, [testCase.Y testCase.X testCase.XmlC 1 numel(testCase.XmlTimesSec)], ...
                'XML framesize should carry channels on the C axis.');
            frames = testCase.Reader.readframes(ef,1);
            testCase.verifyEqual(frames, testCase.XmlTruth, ...
                'XML multi-channel frames did not round-trip.');
        end

        function testXmlTimestamps(testCase)
            ef = {testCase.XmlDir};
            ec = testCase.Reader.epochclock(ef,1);
            testCase.verifyEqual(ec{1}.type, 'dev_local_time', ...
                'XML epoch with per-frame times should be dev_local_time.');
            ft = testCase.Reader.frametimes(ef,1);
            testCase.verifyEqual(ft(:)', testCase.XmlTimesSec, 'AbsTol', 1e-9, ...
                'XML frame times should be the absoluteTime values in seconds.');
        end

        function testV2ConfigParsing(testCase)
            % the embedded XSD schema must be skipped: dims come from the data
            v = ndr.format.prairieview.readconfig(testCase.V2Dir);
            testCase.verifyTrue(v.is_xml, 'v2 XML config should set is_xml=true.');
            testCase.verifyEqual(v.Main.Lines_per_frame, testCase.Y, ...
                'v2 Lines_Per_Frame should be read from the data, not the schema.');
            testCase.verifyEqual(v.Main.Pixels_per_line, testCase.X, ...
                'v2 Pixels_Per_Line should be read from the data, not the schema.');
            testCase.verifyEqual(v.Image_TimeStamp__us_(:)', testCase.V2TimesMs*1e3, ...
                'AbsTol', 1e-6, 'v2 per-frame <Time> (ms->us) mismatch.');
        end

        function testV2GeometryAndTimes(testCase)
            ef = {testCase.V2Dir};
            testCase.verifyEqual(testCase.Reader.numframes(ef,1), numel(testCase.V2TimesMs), ...
                'v2 numframes should equal the number of timepoints.');
            sz = testCase.Reader.framesize(ef,1);
            testCase.verifyEqual(sz, [testCase.Y testCase.X testCase.V2C 1 numel(testCase.V2TimesMs)], ...
                'v2 framesize should carry channels on the C axis.');
            frames = testCase.Reader.readframes(ef,1);
            testCase.verifyEqual(frames, testCase.V2Truth, 'v2 frames did not round-trip.');
            ec = testCase.Reader.epochclock(ef,1);
            testCase.verifyEqual(ec{1}.type, 'dev_local_time', 'v2 epoch should be dev_local_time.');
            ft = testCase.Reader.frametimes(ef,1);
            testCase.verifyEqual(ft(:)', testCase.V2TimesMs/1e3, 'AbsTol', 1e-9, ...
                'v2 frame times should be <Time> (ms) in seconds.');
        end

        function testMultiCyclePcfConfig(testCase)
            v = ndr.format.prairieview.readconfig(testCase.CycDir);
            testCase.verifyEqual(v.Main.Total_images, sum(testCase.CycCounts), ...
                'Total_images should be the sum of the per-cycle image counts.');
            testCase.verifyEqual(numel(v.Image_TimeStamp__us_), sum(testCase.CycCounts), ...
                'There should be one timestamp per frame across all cycles.');
            testCase.verifyEqual(v.Image_TimeStamp__us_(:)', testCase.CycTimesUs, ...
                'AbsTol', 1e-6, 'Multi-cycle [Image TimeStamp (us)] mismatch.');
        end

        function testMultiCycleEpochSpansCycles(testCase)
            % one epoch (the directory) is the whole run, i.e. all cycles;
            % frames are ordered cycle-then-frame and timestamped from the
            % Main.pcf list spanning every cycle.
            ef = {testCase.CycDir};
            T = sum(testCase.CycCounts);
            testCase.verifyEqual(testCase.Reader.numframes(ef,1), T, ...
                'A multi-cycle epoch should expose all cycles'' frames.');
            sz = testCase.Reader.framesize(ef,1);
            testCase.verifyEqual(sz, [testCase.Y testCase.X 1 1 T], 'Multi-cycle framesize mismatch.');
            frames = testCase.Reader.readframes(ef,1);
            testCase.verifyEqual(frames, testCase.CycTruth, ...
                'Multi-cycle frames did not round-trip in cycle-then-frame order.');
            ft = testCase.Reader.frametimes(ef,1);
            testCase.verifyEqual(ft(:)', testCase.CycTimesUs/1e6, 'AbsTol', 1e-9, ...
                'Multi-cycle frame times should span all cycles, in seconds.');
        end

        function testEmptyImageMetadataContract(testCase)
            % the shared "empty" struct defines the standardized field set
            m = ndr.reader.base.emptyimagemetadata();
            testCase.verifyEqual(sort(fieldnames(m)), sort({'israster';'frame_period'; ...
                'line_period';'dwell_time';'lines_per_frame';'pixels_per_line';'bidirectional'}), ...
                'emptyimagemetadata field set mismatch.');
            testCase.verifyFalse(m.israster, 'israster should default false.');
            testCase.verifyFalse(m.bidirectional, 'bidirectional should default false.');
            testCase.verifyTrue(isnan(m.frame_period) && isnan(m.line_period) && ...
                isnan(m.dwell_time), 'timing defaults should be NaN.');
        end

        function testMetadataFromXml(testCase)
            % modern PVScan XML: frame/line/dwell come from the config, in
            % seconds; line_period is the exact scanLinePeriod (not derived)
            m = testCase.Reader.metadata({testCase.XmlDir},1);
            testCase.verifyTrue(m.israster, 'XML raster scan should set israster=true.');
            testCase.verifyEqual(m.frame_period, testCase.FramePeriodSec, 'AbsTol', 1e-9, ...
                'frame_period should be framePeriod (s).');
            testCase.verifyEqual(m.line_period, testCase.ScanLinePeriodSec, 'AbsTol', 1e-12, ...
                'line_period should be the exact scanLinePeriod (s).');
            testCase.verifyEqual(m.dwell_time, testCase.DwellTimeUs/1e6, 'AbsTol', 1e-15, ...
                'dwell_time should be dwellTime converted us->s.');
            testCase.verifyEqual(m.lines_per_frame, testCase.Y, 'lines_per_frame mismatch.');
            testCase.verifyEqual(m.pixels_per_line, testCase.X, 'pixels_per_line mismatch.');
            testCase.verifyEqual(m.bidirectional, testCase.BidirectionalTruth, ...
                'bidirectional should be parsed from bidirectionalScan.');
        end

        function testReadframesSelectC(testCase)
            % SelectC on a 2-channel recording returns only the requested
            % channels (prairieview reads only those channel files)
            ef = {testCase.MultiDir};
            % single channel
            f2 = testCase.Reader.readframes(ef,1,[],'SelectC',2);
            testCase.verifyEqual(size(f2,3), 1, 'SelectC=2 should return a single channel.');
            testCase.verifyEqual(f2, testCase.MultiTruth(:,:,2,:,:), 'SelectC=2 returned the wrong channel.');
            % reversed channel order is honored
            f21 = testCase.Reader.readframes(ef,1,[],'SelectC',[2 1]);
            testCase.verifyEqual(f21, testCase.MultiTruth(:,:,[2 1],:,:), 'SelectC=[2 1] order mismatch.');
            % combined with a timepoint (frameind) subset
            f2sub = testCase.Reader.readframes(ef,1,[2 4],'SelectC',1);
            testCase.verifyEqual(f2sub, testCase.MultiTruth(:,:,1,:,[2 4]), 'SelectC + frameind subset mismatch.');
            % default (no SelectC) is unchanged
            fall = testCase.Reader.readframes(ef,1);
            testCase.verifyEqual(fall, testCase.MultiTruth, 'Default readframes (all channels) should be unchanged.');
        end

        function testMetadataDerivedLinePeriod(testCase)
            % legacy .pcf has a frame period but no scanLinePeriod, so
            % line_period is derived as frame_period / lines_per_frame, and
            % there is no dwell time
            m = testCase.Reader.metadata({testCase.DirEpoch},1);
            testCase.verifyTrue(m.israster, 'A .pcf with a frame period should set israster=true.');
            testCase.verifyEqual(m.frame_period, 0.25, 'AbsTol', 1e-9, ...
                'frame_period should be Frame period (us)=250000 in seconds.');
            testCase.verifyEqual(m.line_period, 0.25/testCase.Y, 'AbsTol', 1e-12, ...
                'line_period should be derived as frame_period / lines_per_frame.');
            testCase.verifyTrue(isnan(m.dwell_time), '.pcf has no dwell time -> NaN.');
            testCase.verifyFalse(m.bidirectional, 'No bidirectional key -> false.');
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

        function writePVScanXml(filename, Y, X, timesSec)
            % Write a PVScan XML in the real Prairie v4 layout: one
            % <Sequence cycle="N"> per timepoint, each with a single <Frame>
            % carrying its absoluteTime, the per-channel <File> entries, and a
            % per-frame <PVStateShard> with the dimension Keys (note the
            % 'permissions' attribute sits between key and value, as in real
            % files).
            fid = fopen(filename,'w');
            c = onCleanup(@() fclose(fid));
            fprintf(fid,'<?xml version="1.0" encoding="utf-8"?>\n');
            fprintf(fid,'<PVScan version="4.0.0.43" date="9/28/2018 5:40:34 PM" notes="">\n');
            for i=1:numel(timesSec)
                fprintf(fid,'  <Sequence type="TSeries Timed Element" cycle="%d">\n', i);
                fprintf(fid,'    <Frame relativeTime="0" absoluteTime="%.12g" index="1" label="CurrentSettings">\n', timesSec(i));
                fprintf(fid,'      <File channel="1" channelName="Ch1" filename="t00004-001_Cycle%03d_CurrentSettings_Ch1_000001.tif" />\n', i);
                fprintf(fid,'      <File channel="2" channelName="Ch2" filename="t00004-001_Cycle%03d_CurrentSettings_Ch2_000001.tif" />\n', i);
                fprintf(fid,'      <PVStateShard>\n');
                fprintf(fid,'        <Key key="linesPerFrame" permissions="Read, Write, Save" value="%d" />\n', Y);
                fprintf(fid,'        <Key key="pixelsPerLine" permissions="Read, Write, Save" value="%d" />\n', X);
                fprintf(fid,'        <Key key="framePeriod" permissions="Read, Write, Save" value="%.12g" />\n', ndr.unittest.reader.TestPrairieView.FramePeriodSec);
                fprintf(fid,'        <Key key="scanLinePeriod" permissions="Read, Write, Save" value="%.12g" />\n', ndr.unittest.reader.TestPrairieView.ScanLinePeriodSec);
                fprintf(fid,'        <Key key="dwellTime" permissions="Read, Write, Save" value="%.12g" />\n', ndr.unittest.reader.TestPrairieView.DwellTimeUs);
                fprintf(fid,'        <Key key="bidirectionalScan" permissions="Read, Write, Save" value="True" />\n');
                fprintf(fid,'      </PVStateShard>\n');
                fprintf(fid,'    </Frame>\n');
                fprintf(fid,'  </Sequence>\n');
            end
            fprintf(fid,'</PVScan>\n');
        end

        function writeMultiCyclePcf(filename, Y, X, cycleCounts, timesUs)
            % Write a real-style multi-cycle legacy .pcf: [Main] with the
            % total image count, one [Cycle N] section per cycle (with its
            % image count), and an [Image TimeStamp (us)] list spanning every
            % cycle (one entry per frame, in cycle-then-frame order).
            fid = fopen(filename,'w');
            c = onCleanup(@() fclose(fid));
            fprintf(fid,'[Main]\n');
            fprintf(fid,'Acquisition type=TSERIES_MAIN\n');
            fprintf(fid,'Bit depth=12\n');
            fprintf(fid,'Channel 1 active=True\n');
            fprintf(fid,'Frame period (us)=1486848.0\n');
            fprintf(fid,'Lines per frame=%d\n', Y);
            fprintf(fid,'Pixels per line=%d\n', X);
            fprintf(fid,'Total cycles=%d\n', numel(cycleCounts));
            fprintf(fid,'Total images=%d\n', sum(cycleCounts));
            fprintf(fid,'Version=2.1.0.2\n');
            fprintf(fid,'\n');
            for k=1:numel(cycleCounts)
                fprintf(fid,'[Cycle %d]\n', k);
                fprintf(fid,'Acquisition type=TSERIES_CYCLE\n');
                fprintf(fid,'Number of frames to average=1\n');
                fprintf(fid,'Number of images=%d\n', cycleCounts(k));
                fprintf(fid,'Period (us)=0.0\n');
                fprintf(fid,'\n');
            end
            fprintf(fid,'[Image TimeStamp (us)]\n');
            for i=1:sum(cycleCounts)
                fprintf(fid,'%d=%.15g\n', i, timesUs(i));
            end
        end

        function writeV2Xml(filename, Y, X, timesMs)
            % Write a minimal legacy v2.2 '.NET DataSet' Prairie XML: an
            % embedded <xs:schema> (defining field names, which must be
            % skipped) followed by an <Acquisition_Header> with the real dim
            % values and one <Dataset_x0020_2> frame row per timepoint, each
            % carrying its per-channel filenames and a <Time> in milliseconds.
            fid = fopen(filename,'w');
            c = onCleanup(@() fclose(fid));
            fprintf(fid,'<?xml version="1.0" standalone="yes"?>\n');
            fprintf(fid,'<Acquisition>\n');
            fprintf(fid,'  <xs:schema id="Acquisition" xmlns:xs="http://www.w3.org/2001/XMLSchema">\n');
            fprintf(fid,'    <xs:element name="Lines_Per_Frame" type="xs:double" minOccurs="0" />\n');
            fprintf(fid,'    <xs:element name="Pixels_Per_Line" type="xs:double" minOccurs="0" />\n');
            fprintf(fid,'    <xs:element name="Framerate" type="xs:double" minOccurs="0" />\n');
            fprintf(fid,'    <xs:element name="Time" type="xs:double" minOccurs="0" />\n');
            fprintf(fid,'  </xs:schema>\n');
            fprintf(fid,'  <Acquisition_Header>\n');
            fprintf(fid,'    <Lines_Per_Frame>%d</Lines_Per_Frame>\n', Y);
            fprintf(fid,'    <Pixels_Per_Line>%d</Pixels_Per_Line>\n', X);
            fprintf(fid,'    <Framerate>0.9</Framerate>\n');
            fprintf(fid,'    <Total_Frames>%d</Total_Frames>\n', numel(timesMs));
            fprintf(fid,'  </Acquisition_Header>\n');
            for i=1:numel(timesMs)
                fprintf(fid,'  <Dataset_x0020_2>\n');
                fprintf(fid,'    <Channel_1_Filename>t00001-001_Cycle%03d_Ch1_000001.tif</Channel_1_Filename>\n', i);
                fprintf(fid,'    <Channel_2_Filename>t00001-001_Cycle%03d_Ch2_000001.tif</Channel_2_Filename>\n', i);
                fprintf(fid,'    <Frame>1</Frame>\n');
                fprintf(fid,'    <Time>%.15g</Time>\n', timesMs(i));
                fprintf(fid,'  </Dataset_x0020_2>\n');
            end
            fprintf(fid,'</Acquisition>\n');
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
                fprintf(fid,'%d=%.15g\n', i, timesUs(i));
            end
        end
    end % methods (Static)

end % classdef
