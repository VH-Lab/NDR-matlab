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

        function testEncodeManyRoundtripMatchesSingular(testCase)
            % encodeMany + decodeMany for a batch must match the
            % result of calling encode/decode on each item.
            rng(1);
            items = { ...
                uint16(randi([0 65535], 1, 512)), ...
                uint16(randi([0 65535], 1, 1024)), ...
                uint16(randi([0 65535], 1, 256))};
            rawBytes = cellfun(@(x) typecast(x(:), 'uint8'), items, ...
                'UniformOutput', false);
            batched = ndr.format.blosc.encodeMany(rawBytes, ...
                'typesize', 2);
            testCase.verifyEqual(numel(batched), numel(items));
            for i = 1:numel(items)
                testCase.verifyTrue( ...
                    ndr.format.blosc.isBlosc(batched{i}));
                back = ndr.format.blosc.decode(batched{i});
                recovered = typecast(back, 'uint16');
                testCase.verifyEqual(recovered(:).', items{i}(:).');
            end
        end

        function testDecodeManyMatchesSingular(testCase)
            % decodeMany on a batch of pre-encoded containers must
            % produce byte-identical output to decode on each.
            rng(2);
            items = { ...
                uint16(randi([0 65535], 1, 512)), ...
                uint16(randi([0 65535], 1, 1024))};
            containers = cellfun(@(x) ndr.format.blosc.encode(x), ...
                items, 'UniformOutput', false);
            batchDecoded = ndr.format.blosc.decodeMany(containers);
            for i = 1:numel(items)
                soloDecoded = ndr.format.blosc.decode(containers{i});
                testCase.verifyEqual(batchDecoded{i}, soloDecoded, ...
                    sprintf('item %d differs between batched and ' ...
                        'singular decode', i));
            end
        end

        function testEmptyBatchIsNoop(testCase)
            % Both APIs must accept an empty batch and return an
            % empty cell without spawning a subprocess.
            testCase.verifyEqual(ndr.format.blosc.encodeMany({}, ...
                'typesize', 2), {});
            testCase.verifyEqual(ndr.format.blosc.decodeMany({}), {});
        end

        function testPackUnpackRoundtripIsBitExact(testCase)
            % Wire format helpers must roundtrip. This is the piece
            % blosc_tool.py's server relies on; a bug here would
            % desynchronise the client and server halves.
            rng(3);
            items = { ...
                uint8(randi([0 255], 1, 17))', ...
                uint8(randi([0 255], 1, 0))', ...
                uint8(randi([0 255], 1, 4096))'};
            body = ndr.util.blosc.packBatch(items);
            back = ndr.util.blosc.unpackBatch(body);
            testCase.verifyEqual(numel(back), numel(items));
            for i = 1:numel(items)
                testCase.verifyEqual(back{i}, items{i});
            end
        end
    end
end
