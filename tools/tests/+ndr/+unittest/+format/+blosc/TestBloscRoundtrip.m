classdef TestBloscRoundtrip < matlab.unittest.TestCase
    % TestBloscRoundtrip - encode/decode parity for ndr.format.blosc.
    %
    % These tests trigger ndr.util.blosc.setup on the first call, so they
    % need a working `python3` on PATH and, on a fresh machine, network
    % access to PyPI. When neither is available the tests skip cleanly.
    % Once the venv is warm the round-trip does not touch the network.

    methods (TestClassSetup)
        function ensureVenv(testCase)
            try
                ndr.util.blosc.pythonExe();
            catch ME
                testCase.assumeFail(sprintf( ...
                    'Blosc venv unavailable: %s', ME.message));
            end
        end
    end

    methods (Test)
        function testRoundtripUint16(testCase)
            rng(1);
            data = uint16(randi([0 65535], 1, 4096));
            container = ndr.format.blosc.encode(data);
            testCase.verifyTrue(ndr.format.blosc.isBlosc(container));
            back = ndr.format.blosc.decode(container);
            recovered = typecast(back, 'uint16');
            testCase.verifyEqual(numel(recovered), numel(data));
            testCase.verifyEqual(recovered(:).', data(:).');
        end

        function testRoundtripSingle(testCase)
            data = single(reshape(1:1000, [10 10 10])) / 3.14;
            container = ndr.format.blosc.encode(data);
            back = ndr.format.blosc.decode(container);
            recovered = reshape(typecast(back, 'single'), size(data));
            testCase.verifyEqual(recovered, data);
        end

        function testHeaderReadsBack(testCase)
            data = uint16(zeros(1, 512));
            container = ndr.format.blosc.encode(data);
            h = ndr.format.blosc.header(container);
            testCase.verifyEqual(h.typesize, 2);
            testCase.verifyEqual(h.nbytes, 2 * 512);
            testCase.verifyEqual(h.cbytes, numel(container));
            testCase.verifyTrue(h.hasByteShuffle);
        end

        function testExplicitTypesizeOnBytes(testCase)
            % Raw uint8 stream but caller says typesize=2. Length must be
            % a multiple of typesize; encode records it in the header.
            rawU16 = uint16(1:1024);
            bytes = typecast(rawU16, 'uint8');
            container = ndr.format.blosc.encode(bytes, 'typesize', 2);
            back = ndr.format.blosc.decode(container);
            recovered = typecast(back, 'uint16');
            testCase.verifyEqual(recovered(:).', rawU16(:).');
        end

        function testShuffleOffStillRoundtrips(testCase)
            data = uint16(1:2048);
            container = ndr.format.blosc.encode(data, 'shuffle', 0);
            back = ndr.format.blosc.decode(container);
            recovered = typecast(back, 'uint16');
            testCase.verifyEqual(recovered(:).', data(:).');
        end

        function testIsBloscRejectsRandom(testCase)
            testCase.verifyFalse(ndr.format.blosc.isBlosc(uint8(zeros(1, 4))));
            testCase.verifyFalse(ndr.format.blosc.isBlosc(uint8(255 * ones(1, 32))));
        end

        function testLengthMismatchErrors(testCase)
            % Odd number of bytes with typesize=2 must complain rather
            % than truncate silently.
            bytes = uint8(1:11);
            testCase.verifyError( ...
                @() ndr.format.blosc.encode(bytes, 'typesize', 2), ...
                'ndr:format:blosc:encode:LengthMismatch');
        end

        function testVersionReports(testCase)
            info = ndr.util.blosc.version();
            testCase.verifyClass(info, 'struct');
            testCase.verifyNotEmpty(info.numcodecs);
        end
    end
end
