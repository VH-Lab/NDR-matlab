classdef TestVideo < matlab.unittest.TestCase
    %TESTVIDEO Unit tests for the native ndr.reader.video (VideoReader) reader.
    %
    %   This test class verifies the frame API of ndr.reader.video (numframes,
    %   framesize, dimensionorder, datatype, frametimes, readframes,
    %   epochclock, t0_t1, getchannelsepoch, metadata) using only MATLAB's
    %   built-in VideoWriter/VideoReader. It writes small synthetic videos
    %   with known per-frame content into a temporary folder:
    %
    %     - an RGB video, written as 'MPEG-4' when the platform can write it
    %       and otherwise as 'Motion JPEG AVI' (Linux runners cannot write
    %       MPEG-4). Both are lossy, so pixel content is compared through
    %       per-frame, per-channel means with a tolerance;
    %     - a greyscale video written as 'Grayscale AVI' (lossless), which
    %       checks the C=1 path and exact pixel round-trip.
    %
    %   The class handles creation and cleanup of all temporary files.

    properties (Constant)
        Y = 24;          % frame height
        X = 32;          % frame width
        T = 12;          % number of frames
        FrameRate = 4;   % frames per second
        MeanTol = 6;     % tolerance on per-frame channel means for lossy codecs
    end

    properties (SetAccess=protected)
        Reader              % the ndr.reader object instance ('video')
        TempDir char        % temporary directory for test files
        RGBTruth            % Y x X x 3 x 1 x T uint8 ground truth
        RGBFile char        % RGB video file (MPEG-4 or Motion JPEG AVI)
        RGBProfile char     % the VideoWriter profile actually used
        GreyTruth           % Y x X x 1 x 1 x T uint8 ground truth
        GreyFile char       % greyscale video file ('Grayscale AVI')
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            testCase.TempDir = fullfile(tempdir, ['ndr_video_test_' char(java.util.UUID.randomUUID)]);
            if ~isfolder(testCase.TempDir)
                mkdir(testCase.TempDir);
            end

            testCase.Reader = ndr.reader('video');
            testCase.assertClass(testCase.Reader, 'ndr.reader', 'Reader initialization failed.');

            Yl = testCase.Y; Xl = testCase.X; Tl = testCase.T;

            % RGB truth: each frame is flat per channel with a frame-dependent
            % level, and the three channels differ, so both frame order and
            % channel order are checked. Flat frames survive lossy codecs well.
            rgb = zeros(Yl, Xl, 3, 1, Tl, 'uint8');
            for i=1:Tl
                level = 20 + (i-1)*18;          % 20 .. 218
                rgb(:,:,1,1,i) = level;
                rgb(:,:,2,1,i) = 255 - level;
                rgb(:,:,3,1,i) = 128;
            end
            testCase.RGBTruth = rgb;

            % write the RGB video: MPEG-4 if possible, else Motion JPEG AVI
            [testCase.RGBFile, testCase.RGBProfile] = ...
                ndr.unittest.reader.TestVideo.writeRGBVideo(testCase.TempDir, 'rgbvideo', ...
                rgb, testCase.FrameRate);
            testCase.assumeNotEmpty(testCase.RGBFile, ...
                'Neither MPEG-4 nor Motion JPEG AVI could be written on this platform.');

            % greyscale truth: a spatial gradient plus a frame-dependent offset
            grey = zeros(Yl, Xl, 1, 1, Tl, 'uint8');
            base = reshape(0:(Yl*Xl-1), Yl, Xl);
            for i=1:Tl
                grey(:,:,1,1,i) = uint8(mod(base + (i-1)*7, 200));
            end
            testCase.GreyTruth = grey;
            testCase.GreyFile = fullfile(testCase.TempDir, 'greyvideo.avi');
            w = VideoWriter(testCase.GreyFile, 'Grayscale AVI');
            w.FrameRate = testCase.FrameRate;
            open(w);
            for i=1:Tl
                writeVideo(w, grey(:,:,1,1,i));
            end
            close(w);
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

        function testKnownReaders(testCase)
            kr = ndr.known_readers();
            testCase.verifyTrue(any(strcmp(kr, 'video')), ...
                'ndr.known_readers() should list ''video''.');
            testCase.verifyClass(testCase.Reader.ndr_reader_base, 'ndr.reader.video', ...
                'ndr.reader(''video'') should dispatch to ndr.reader.video.');
        end

        function testNumFramesAndSize(testCase)
            ef = {testCase.RGBFile};
            testCase.verifyEqual(testCase.Reader.numframes(ef,1), testCase.T, ...
                sprintf('numframes mismatch (%s).', testCase.RGBProfile));
            sz = testCase.Reader.framesize(ef,1);
            testCase.verifyEqual(sz, [testCase.Y testCase.X 3 1 testCase.T], ...
                sprintf('framesize mismatch (%s).', testCase.RGBProfile));
        end

        function testDimensionOrderAndDatatype(testCase)
            ef = {testCase.RGBFile};
            testCase.verifyEqual(testCase.Reader.dimensionorder(ef,1), 'YXCZT', ...
                'dimensionorder mismatch.');
            testCase.verifyEqual(testCase.Reader.datatype(ef,1), 'uint8', ...
                'datatype mismatch.');
        end

        function testClockAndTimes(testCase)
            ef = {testCase.RGBFile};
            ec = testCase.Reader.epochclock(ef,1);
            testCase.verifyNumElements(ec, 1, 'Expected one clock type.');
            testCase.verifyEqual(ec{1}.type, 'dev_local_time', ...
                'Video epoch should be dev_local_time.');

            ft = testCase.Reader.frametimes(ef,1);
            testCase.verifySize(ft, [testCase.T 1], 'frametimes should be T x 1.');
            expected = (0:testCase.T-1)' / testCase.FrameRate;
            testCase.verifyEqual(ft, expected, 'AbsTol', 1e-3, ...
                sprintf('frametimes should be (k-1)/FrameRate (%s).', testCase.RGBProfile));
            testCase.verifyEqual(diff(ft), repmat(1/testCase.FrameRate, testCase.T-1, 1), ...
                'AbsTol', 1e-3, 'frame spacing should be 1/FrameRate.');

            ftsub = testCase.Reader.frametimes(ef,1,[2 5 9]);
            testCase.verifyEqual(ftsub, ft([2 5 9]), 'frametimes subset mismatch.');

            t0t1 = testCase.Reader.t0_t1(ef,1);
            testCase.verifyEqual(t0t1{1}, [ft(1) ft(end)], 't0_t1 mismatch.');
        end

        function testFramesContent(testCase)
            ef = {testCase.RGBFile};
            frames = testCase.Reader.readframes(ef,1);
            testCase.verifySize(frames, [testCase.Y testCase.X 3 1 testCase.T], ...
                'readframes size mismatch.');
            testCase.verifyClass(frames, 'uint8', 'readframes class mismatch.');
            testCase.verifyEqual(ndr.unittest.reader.TestVideo.channelMeans(frames), ...
                ndr.unittest.reader.TestVideo.channelMeans(testCase.RGBTruth), ...
                'AbsTol', testCase.MeanTol, ...
                sprintf('Per-frame channel means differ from the written video (%s).', testCase.RGBProfile));
        end

        function testRandomAccessSubset(testCase)
            ef = {testCase.RGBFile};
            all_frames = testCase.Reader.readframes(ef,1);
            idx = [7 2 3 4 12 1];   % out of order, with a consecutive run
            subset = testCase.Reader.readframes(ef,1,idx);
            testCase.verifySize(subset, [testCase.Y testCase.X 3 1 numel(idx)], ...
                'readframes subset size mismatch.');
            testCase.verifyEqual(subset, all_frames(:,:,:,:,idx), ...
                'Random-access frames differ from the same frames read sequentially.');
            testCase.verifyEqual(ndr.unittest.reader.TestVideo.channelMeans(subset), ...
                ndr.unittest.reader.TestVideo.channelMeans(testCase.RGBTruth(:,:,:,:,idx)), ...
                'AbsTol', testCase.MeanTol, 'Random-access frame content mismatch.');
            one = testCase.Reader.readframes(ef,1,5);
            testCase.verifyEqual(one, all_frames(:,:,:,:,5), 'Single-frame read mismatch.');
        end

        function testSelectC(testCase)
            ef = {testCase.RGBFile};
            g = testCase.Reader.readframes(ef,1,[1 2],'SelectC',2);
            testCase.verifySize(g, [testCase.Y testCase.X 1 1 2], 'SelectC size mismatch.');
            all_frames = testCase.Reader.readframes(ef,1,[1 2]);
            testCase.verifyEqual(g, all_frames(:,:,2,:,:), 'SelectC content mismatch.');
        end

        function testGreyscaleVideo(testCase)
            ef = {testCase.GreyFile};
            testCase.verifyEqual(testCase.Reader.numframes(ef,1), testCase.T, ...
                'Greyscale numframes mismatch.');
            testCase.verifyEqual(testCase.Reader.framesize(ef,1), ...
                [testCase.Y testCase.X 1 1 testCase.T], 'Greyscale framesize mismatch (C should be 1).');
            testCase.verifyEqual(testCase.Reader.datatype(ef,1), 'uint8', ...
                'Greyscale datatype mismatch.');
            frames = testCase.Reader.readframes(ef,1);
            testCase.verifyEqual(frames, testCase.GreyTruth, ...
                'Lossless greyscale frames did not round-trip.');
            subset = testCase.Reader.readframes(ef,1,[10 3]);
            testCase.verifyEqual(subset, testCase.GreyTruth(:,:,:,:,[10 3]), ...
                'Greyscale random-access subset did not round-trip.');
            ft = testCase.Reader.frametimes(ef,1);
            testCase.verifyEqual(ft, (0:testCase.T-1)'/testCase.FrameRate, 'AbsTol', 1e-3, ...
                'Greyscale frametimes mismatch.');
        end

        function testCompanionFilesIgnored(testCase)
            % NDI's file navigator passes companion files (e.g. an
            % epochprobemap) alongside the video; they must be ignored.
            companion = fullfile(testCase.TempDir, 'epochprobemap.ndi');
            fid = fopen(companion, 'w');
            fprintf(fid, 'name reference type\n');
            fclose(fid);
            ef = {companion, testCase.GreyFile};
            testCase.verifyEqual(testCase.Reader.numframes(ef,1), testCase.T, ...
                'Companion file should be ignored.');
            testCase.verifyEqual(testCase.Reader.readframes(ef,1,1), testCase.GreyTruth(:,:,:,:,1), ...
                'Companion file should not change the frames read.');
        end

        function testExactlyOneVideoFile(testCase)
            testCase.verifyError(@() testCase.Reader.numframes({testCase.RGBFile, testCase.GreyFile},1), ...
                'ndr:reader:video:multiplevideofiles');
            txt = fullfile(testCase.TempDir, 'notes.txt');
            fid = fopen(txt, 'w');
            fprintf(fid, 'no video here\n');
            fclose(fid);
            testCase.verifyError(@() testCase.Reader.numframes({txt},1), ...
                'ndr:reader:video:novideofile');
        end

        function testBadFrameIndex(testCase)
            ef = {testCase.GreyFile};
            testCase.verifyError(@() testCase.Reader.readframes(ef,1,testCase.T+1), ...
                'ndr:reader:video:badframeind');
            testCase.verifyError(@() testCase.Reader.frametimes(ef,1,0), ...
                'ndr:reader:video:badframeind');
        end

        function testChannelsAndMetadata(testCase)
            ef = {testCase.RGBFile};
            channels = testCase.Reader.getchannelsepoch(ef,1);
            testCase.verifyNumElements(channels, 1, 'Expected a single image channel.');
            testCase.verifyEqual(channels(1).type, 'image', 'Channel type should be image.');
            m = testCase.Reader.metadata(ef,1);
            testCase.verifyFalse(m.israster, 'A video is not a raster scan.');
            testCase.verifyEqual(m.frame_period, 1/testCase.FrameRate, 'AbsTol', 1e-6, ...
                'metadata frame_period should be 1/FrameRate.');
        end

    end % methods (Test)

    methods (Static)
        function [filename, profile] = writeRGBVideo(folder, basename, rgb, frameRate)
            % WRITERGBVIDEO - write RGB frames as MPEG-4, falling back to Motion JPEG AVI
            %
            % Returns the file written and the VideoWriter profile used, or
            % empty values if no profile could be written.
            candidates = {'MPEG-4', '.mp4'; 'Motion JPEG AVI', '.avi'};
            filename = '';
            profile = '';
            for c=1:size(candidates,1)
                fn = fullfile(folder, [basename candidates{c,2}]);
                try
                    w = VideoWriter(fn, candidates{c,1});
                    w.FrameRate = frameRate;
                    w.Quality = 100;
                    open(w);
                    for i=1:size(rgb,5)
                        writeVideo(w, rgb(:,:,:,1,i));
                    end
                    close(w);
                    filename = fn;
                    profile = candidates{c,1};
                    return;
                catch
                    if isfile(fn)
                        delete(fn);
                    end
                end
            end
        end

        function m = channelMeans(frames)
            % CHANNELMEANS - C x T matrix of per-frame, per-channel means of a YXCZT array
            sz = size(frames);
            if numel(sz)<5, sz(end+1:5) = 1; end
            m = reshape(mean(mean(double(frames),1),2), sz(3), sz(5));
        end
    end % methods (Static)

end % classdef
