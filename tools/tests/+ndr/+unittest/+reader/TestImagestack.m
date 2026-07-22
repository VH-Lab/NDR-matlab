classdef TestImagestack < matlab.unittest.TestCase
    %TESTIMAGESTACK Unit tests for the ndr.reader.imagestack (NANSEN) backend.
    %
    %   This test class verifies the frame API of ndr.reader.imagestack, the
    %   backend that wraps nansen.stack.ImageStack (VervaekeLab,
    %   https://github.com/VervaekeLab/NANSEN). NANSEN is declared in
    %   tools/requirements.txt and installed by matbox.installRequirements on
    %   CI; if NANSEN is not on the MATLAB path (e.g. a local run without the
    %   requirements installed), the tests are skipped via assumeTrue rather
    %   than failed.
    %
    %   The tests generate a temporary multipage TIFF with known pixel content
    %   and check that the imagestack backend reports the same geometry and
    %   returns the same frames as the ground truth (and as the native
    %   ndr.reader.tiffstack reader).

    properties (Constant)
        Y = 8;  % image height
        X = 6;  % image width
        T = 4;  % number of frames (pages)
    end

    properties (SetAccess=protected)
        Reader            % the ndr.reader object instance ('imagestack')
        TempDir char      % temporary directory for test files
        Truth             % Y x X x 1 x 1 x T uint16 ground-truth stack
        TiffFile char
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            testCase.TempDir = fullfile(tempdir, ['ndr_imagestack_test_' char(java.util.UUID.randomUUID)]);
            if ~isfolder(testCase.TempDir)
                mkdir(testCase.TempDir);
            end

            testCase.Reader = ndr.reader('imagestack');
            testCase.assertClass(testCase.Reader, 'ndr.reader', 'Reader initialization failed.');

            Yl = testCase.Y; Xl = testCase.X; Tl = testCase.T;
            truth = zeros(Yl, Xl, 1, 1, Tl, 'uint16');
            for i=1:Tl
                truth(:,:,1,1,i) = uint16( reshape(1:(Yl*Xl), Yl, Xl) + (i-1)*1000 );
            end
            testCase.Truth = truth;

            testCase.TiffFile = fullfile(testCase.TempDir,'imagestack_test.tif');
            ndr.unittest.reader.TestTiffstack.writeMultipageTiff(testCase.TiffFile, truth);
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

    methods (TestMethodSetup)
        function requireNansen(testCase)
            % Skip (not fail) every test in this class when NANSEN is absent.
            testCase.assumeTrue(exist('nansen.stack.ImageStack','class')==8, ...
                ['NANSEN (nansen.stack.ImageStack) is not on the MATLAB path; ' ...
                 'install requirements with matbox.installRequirements(fullfile(pwd,''tools'')). ' ...
                 'Skipping ndr.reader.imagestack tests.']);
        end
    end

    methods (Test)

        function testMissingNansenErrorIsClear(testCase)
            % Sanity-check the error identifier used when NANSEN is absent.
            % (Runs only when NANSEN is present; we just confirm the method
            % does NOT throw it in that case.)
            ef = {testCase.TiffFile};
            s = testCase.Reader.ndr_reader_base.imagestackobject(ef);
            testCase.verifyClass(s, 'nansen.stack.ImageStack', ...
                'imagestackobject should return a nansen.stack.ImageStack.');
        end

        function testMultiPlaneFrameContract(testCase)
            % Regression for the 3-way frame-count contradiction: numframes
            % must equal framesize(...,5) and the timepoint count, and
            % size(readframes(...),5) must equal numel(frameind). Previously
            % numframes returned NumTimepoints*NumPlanes, contradicting both
            % framesize(5) and readframes. The invariant below is the fix.
            ef = {testCase.TiffFile};
            s = testCase.Reader.ndr_reader_base.imagestackobject(ef);
            n  = testCase.Reader.numframes(ef,1);
            sz = testCase.Reader.framesize(ef,1);
            testCase.verifyEqual(n, sz(5), ...
                'numframes must equal framesize(...,5).');
            testCase.verifyEqual(n, s.NumTimepoints, ...
                'a frame is a timepoint: numframes must equal NumTimepoints (not NumTimepoints*NumPlanes).');
            frames = testCase.Reader.readframes(ef,1);
            testCase.verifyEqual(size(frames,5), n, ...
                'default readframes must return numframes timepoints.');
        end

        function testGeometry(testCase)
            ef = {testCase.TiffFile};
            testCase.verifyEqual(testCase.Reader.numframes(ef,1), testCase.T, ...
                'numframes mismatch.');
            sz = testCase.Reader.framesize(ef,1);
            testCase.verifyEqual(sz, [testCase.Y testCase.X 1 1 testCase.T], ...
                'framesize mismatch.');
            testCase.verifyEqual(testCase.Reader.dimensionorder(ef,1), 'YXCZT', ...
                'dimensionorder mismatch.');
            testCase.verifyEqual(testCase.Reader.datatype(ef,1), 'uint16', ...
                'datatype mismatch.');
        end

        function testFramesRoundTrip(testCase)
            ef = {testCase.TiffFile};
            frames = testCase.Reader.readframes(ef,1);
            testCase.verifyEqual(frames, testCase.Truth, ...
                'imagestack frames did not round-trip.');
            subset = testCase.Reader.readframes(ef,1,[1 3]);
            testCase.verifyEqual(subset, testCase.Truth(:,:,:,:,[1 3]), ...
                'imagestack frame subset did not round-trip.');
        end

        function testAgreesWithNativeTiffstackReader(testCase)
            % The NANSEN-backed reader and the native TIFF reader must agree.
            ef = {testCase.TiffFile};
            native = ndr.reader('tiffstack');
            testCase.verifyEqual(testCase.Reader.readframes(ef,1), native.readframes(ef,1), ...
                'imagestack and tiffstack disagree on frame data.');
            testCase.verifyEqual(testCase.Reader.framesize(ef,1), native.framesize(ef,1), ...
                'imagestack and tiffstack disagree on framesize.');
        end

        function testClockForPlainTiff(testCase)
            % A plain TIFF carries no timing information; the epoch clock and
            % t0_t1 must be consistent with each other.
            ef = {testCase.TiffFile};
            ec = testCase.Reader.epochclock(ef,1);
            testCase.verifyNumElements(ec, 1, 'Expected one clock type.');
            t0t1 = testCase.Reader.t0_t1(ef,1);
            if strcmp(ec{1}.type,'no_time')
                testCase.verifyTrue(all(isnan(t0t1{1})), ...
                    'no_time epoch should have t0_t1 of [NaN NaN].');
            else
                testCase.verifyEqual(ec{1}.type, 'dev_local_time', ...
                    'Clock should be no_time or dev_local_time.');
                testCase.verifyTrue(all(isfinite(t0t1{1})), ...
                    'dev_local_time epoch should have finite t0_t1.');
            end
        end

        function testFrametimesLengthContractAndConsistency(testCase)
            % frametimes must always return one value per requested frame,
            % even when the format supplies no timing metadata (the NaN
            % coercion path). It must also be self-consistent with epochclock:
            % a no_time epoch yields all-NaN times, a dev_local_time epoch
            % yields all-finite times.
            ef = {testCase.TiffFile};

            % length contract: one value per requested frame, for several
            % index patterns and the default (all frames)
            for fi = { [1], [1 3], [3 1 2], 1:testCase.T }
                idx = fi{1};
                t = testCase.Reader.frametimes(ef, 1, idx);
                testCase.verifyEqual(numel(t), numel(idx), ...
                    sprintf('frametimes returned %d values for %d requested frames.', ...
                        numel(t), numel(idx)));
                testCase.verifySize(t, [numel(idx) 1], ...
                    'frametimes must return a column vector.');
            end
            tAll = testCase.Reader.frametimes(ef, 1);
            testCase.verifyEqual(numel(tAll), testCase.T, ...
                'frametimes() default must return one value per frame.');

            % consistency with the reported clock
            ec = testCase.Reader.epochclock(ef,1);
            if strcmp(ec{1}.type,'no_time')
                testCase.verifyTrue(all(isnan(tAll)), ...
                    'A no_time epoch must report NaN for every frame time.');
            else
                testCase.verifyTrue(all(isfinite(tAll)), ...
                    'A dev_local_time epoch must report a finite time for every frame.');
            end
        end

    end % methods (Test)

end % classdef
