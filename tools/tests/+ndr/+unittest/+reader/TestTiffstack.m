classdef TestTiffstack < matlab.unittest.TestCase
    %TESTTIFFSTACK Unit tests for the ndr.reader.tiffstack image/frame API.
    %
    %   This test class verifies the frame-based reading interface of the
    %   ndr.reader.tiffstack class (numframes, framesize, dimensionorder,
    %   datatype, frametimes, readframes, epochclock, t0_t1), independently of
    %   NDI. It programmatically generates temporary multipage TIFF stacks with
    %   known pixel contents and checks the reader against them.
    %
    %   Two cases are covered:
    %     - A clockless stack (no frame-times sidecar): epochclock 'no_time',
    %       t0_t1 [NaN NaN], frametimes NaN.
    %     - A movie stack (with a '<name>_frametimes.txt' sidecar): epochclock
    %       'dev_local_time', t0_t1 [first last], frametimes match the sidecar.
    %
    %   The class handles creation and cleanup of all temporary files.

    properties (Constant)
        Y = 8;   % image height
        X = 6;   % image width
        T = 5;   % number of frames (pages)
    end

    properties (SetAccess=protected)
        Reader            % the ndr.reader object instance
        TempDir char      % temporary directory for test files
        Truth             % Y x X x 1 x 1 x T uint16 ground-truth stack
        ClocklessFile char
        MovieFile char
        MovieTimes double % frame times written for the movie case
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            testCase.TempDir = fullfile(tempdir, ['ndr_tiff_test_' char(java.util.UUID.randomUUID)]);
            if ~isfolder(testCase.TempDir)
                mkdir(testCase.TempDir);
            end

            testCase.Reader = ndr.reader('tiffstack');
            testCase.assertClass(testCase.Reader, 'ndr.reader', 'Reader initialization failed.');

            % ground-truth stack
            Yl = testCase.Y; Xl = testCase.X; Tl = testCase.T;
            truth = zeros(Yl, Xl, 1, 1, Tl, 'uint16');
            for i=1:Tl
                truth(:,:,1,1,i) = uint16( reshape(1:(Yl*Xl), Yl, Xl) + (i-1)*1000 );
            end
            testCase.Truth = truth;

            % clockless stack
            testCase.ClocklessFile = fullfile(testCase.TempDir,'stack_clockless.tif');
            ndr.unittest.reader.TestTiffstack.writeMultipageTiff(testCase.ClocklessFile, truth);

            % movie stack + frame-times sidecar
            testCase.MovieFile = fullfile(testCase.TempDir,'stack_movie.tif');
            ndr.unittest.reader.TestTiffstack.writeMultipageTiff(testCase.MovieFile, truth);
            testCase.MovieTimes = (0:Tl-1)' * 0.1 + 10;
            ndr.unittest.reader.TestTiffstack.writeAscii( ...
                fullfile(testCase.TempDir,'stack_movie_frametimes.txt'), testCase.MovieTimes);
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

        function testNumFramesAndSize(testCase)
            ef = {testCase.ClocklessFile};
            testCase.verifyEqual(testCase.Reader.numframes(ef,1), testCase.T, ...
                'numframes mismatch.');
            sz = testCase.Reader.framesize(ef,1);
            testCase.verifyEqual(sz, [testCase.Y testCase.X 1 1 testCase.T], ...
                'framesize mismatch.');
        end

        function testDimensionOrderAndDatatype(testCase)
            ef = {testCase.ClocklessFile};
            testCase.verifyEqual(testCase.Reader.dimensionorder(ef,1), 'YXCZT', ...
                'dimensionorder mismatch.');
            testCase.verifyEqual(testCase.Reader.datatype(ef,1), 'uint16', ...
                'datatype mismatch.');
        end

        function testClocklessClockAndTimes(testCase)
            ef = {testCase.ClocklessFile};
            ec = testCase.Reader.epochclock(ef,1);
            testCase.verifyNumElements(ec, 1, 'Expected one clock type.');
            testCase.verifyEqual(ec{1}.type, 'no_time', 'Clockless epoch should be no_time.');
            t0t1 = testCase.Reader.t0_t1(ef,1);
            testCase.verifyTrue(all(isnan(t0t1{1})), 'Clockless t0_t1 should be [NaN NaN].');
            ft = testCase.Reader.frametimes(ef,1);
            testCase.verifyTrue(all(isnan(ft)) && numel(ft)==testCase.T, ...
                'Clockless frametimes should be NaN.');
        end

        function testClocklessFramesRoundTrip(testCase)
            ef = {testCase.ClocklessFile};
            frames = testCase.Reader.readframes(ef,1);
            testCase.verifyEqual(frames, testCase.Truth, 'Clockless frames did not round-trip.');
            subset = testCase.Reader.readframes(ef,1,[2 4]);
            testCase.verifyEqual(subset, testCase.Truth(:,:,:,:,[2 4]), ...
                'Clockless frame subset did not round-trip.');
        end

        function testMovieClockAndTimes(testCase)
            ef = {testCase.MovieFile};
            ec = testCase.Reader.epochclock(ef,1);
            testCase.verifyEqual(ec{1}.type, 'dev_local_time', ...
                'Movie epoch should be dev_local_time.');
            t0t1 = testCase.Reader.t0_t1(ef,1);
            testCase.verifyEqual(t0t1{1}, [testCase.MovieTimes(1) testCase.MovieTimes(end)], ...
                'Movie t0_t1 mismatch.');
            ft = testCase.Reader.frametimes(ef,1);
            testCase.verifyEqual(ft, testCase.MovieTimes, 'Movie frametimes mismatch.');
            ftsub = testCase.Reader.frametimes(ef,1,[1 3 5]);
            testCase.verifyEqual(ftsub, testCase.MovieTimes([1 3 5]), ...
                'Movie frametimes subset mismatch.');
        end

        function testMovieFramesRoundTrip(testCase)
            ef = {testCase.MovieFile};
            frames = testCase.Reader.readframes(ef,1);
            testCase.verifyEqual(frames, testCase.Truth, 'Movie frames did not round-trip.');
        end

        function testGetChannelsEpoch(testCase)
            ef = {testCase.ClocklessFile};
            channels = testCase.Reader.getchannelsepoch(ef,1);
            testCase.verifyNumElements(channels, 1, 'Expected a single image channel.');
            testCase.verifyEqual(channels(1).type, 'image', 'Channel type should be image.');
        end

    end % methods (Test)

    methods (Static)
        function writeMultipageTiff(filename, data)
            sz = size(data);
            if numel(sz)<5, sz(end+1:5) = 1; end
            T = sz(5);
            t = Tiff(filename,'w');
            c = onCleanup(@() t.close());
            for i=1:T
                tags.ImageLength = sz(1);
                tags.ImageWidth = sz(2);
                tags.Photometric = Tiff.Photometric.MinIsBlack;
                tags.BitsPerSample = 16;
                tags.SamplesPerPixel = sz(3);
                tags.SampleFormat = Tiff.SampleFormat.UInt;
                tags.PlanarConfiguration = Tiff.PlanarConfiguration.Chunky;
                tags.Compression = Tiff.Compression.None;
                t.setTag(tags);
                t.write(squeeze(data(:,:,:,1,i)));
                if i<T
                    t.writeDirectory();
                end
            end
        end

        function writeAscii(filename, v)
            fid = fopen(filename,'w');
            c = onCleanup(@() fclose(fid));
            fprintf(fid,'%.10g\n', v);
        end
    end % methods (Static)

end % classdef
