classdef TestSpikegadgetsRecSeek < matlab.unittest.TestCase
    % TESTSPIKEGADGETSRECSEEK - Ground-truth regression tests for the
    % SpikeGadgets (.rec) low-level readers' start-sample (s0) and packet-size
    % handling.
    %
    % These tests synthesize a minimal raw .rec-style file (a '</Configuration>'
    % marker followed by fixed-size packets) with a KNOWN ramp on one aux byte,
    % one digital bit, and one trode channel, and known per-packet timestamps.
    % They call the ndr.format.spikegadgets.read_rec_* functions directly, so no
    % XML config parsing is involved and the expected values are exact.
    %
    % Packet layout (native byte order), matching the readers:
    %   [ header : H int16 ] [ timestamp : uint32 ] [ data : C int16 ]
    %   packetSizeBytes = H*2 + 4 + C*2
    %
    % Regressions covered:
    %   - aux/digital readers ignored s0 (returned samples from t=0 always)
    %   - trode seek used a 2-byte-short packet (header+2+channel) so reads
    %     landed on the wrong packet/channel
    %   - trode timestamps ignored s0

    properties (Constant)
        H  = 2;       % header int16 count  -> headerSizeBytes = 4
        C  = 4;       % data channels       -> channelSizeBytes = 8
        P  = 2000;    % number of packets/samples
        SR = 30000;   % sampling rate (Hz)
    end

    properties (SetAccess=protected)
        RecFile char
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            d = fullfile(tempdir, ['ndr_sg_seek_' char(java.util.UUID.randomUUID)]);
            mkdir(d);
            testCase.addTeardown(@() rmdir(d,'s'));
            testCase.RecFile = fullfile(d,'synthetic.rec');

            P = testCase.P; H = testCase.H; C = testCase.C;
            hdr  = zeros(P,H,'int16');
            hdr(:,1) = int16(1:P);          % aux ramp on header int16 #1 / byte 0-1
            ts   = uint32(0:P-1);           % timestamp p-1 at packet p
            chan = zeros(P,C,'int16');
            chan(:,1) = int16(1:P);         % trode ramp on data channel 1
            TestSpikegadgetsRecSeek.writeSyntheticRec(testCase.RecFile, hdr, ts, chan);
        end
    end

    methods (Test)
        function testConfigsizeHelperGroundTruth(testCase)
            % The shared helper must return the byte offset of the first packet
            % ('</Configuration>' start + 16). Our config region is exactly the
            % 16-char tag + 1 pad byte = 17 bytes.
            testCase.verifyEqual( ...
                ndr.format.spikegadgets.configsize(testCase.RecFile), 17);
        end

        function testAnalogHonorsS0(testCase)
            % The aux reader must return the requested window [s0,s1], not
            % samples from t=0. Ground truth: aux byte holds int16(p).
            [d1000, ts1] = ndr.format.spikegadgets.read_rec_analogChannels( ...
                testCase.RecFile, num2str(testCase.C), 1, testCase.SR, ...
                num2str(testCase.H), 1, 1000);
            [dhi, tshi] = ndr.format.spikegadgets.read_rec_analogChannels( ...
                testCase.RecFile, num2str(testCase.C), 1, testCase.SR, ...
                num2str(testCase.H), 1001, 2000);
            testCase.verifyEqual(d1000(:).', int16(1:1000));
            testCase.verifyEqual(dhi(:).',   int16(1001:2000));
            % the two windows must differ (they returned the same chunk before)
            testCase.verifyNotEqual(dhi(:).', d1000(:).');
            % timestamps honor s0 as well
            testCase.verifyEqual(ts1(1),   0,               'AbsTol', 1e-12);
            testCase.verifyEqual(tshi(1),  1000/testCase.SR, 'AbsTol', 1e-12);
        end

        function testDigitalHonorsS0(testCase)
            % The digital reader must return the requested window. Ground
            % truth: bit 1 of the aux byte = mod(p,2).
            d = ndr.format.spikegadgets.read_rec_digitalChannels( ...
                testCase.RecFile, num2str(testCase.C), [1 1], testCase.SR, ...
                num2str(testCase.H), 1001, 1010);
            testCase.verifyEqual(double(d(:).'), mod(1001:1010, 2));
        end

        function testTrodePacketAlignment(testCase)
            % The trode reader must seek by the TRUE packet size, so reading
            % [1001,2000] returns exactly the ramp for those packets. (A
            % differ-between-chunks test would pass even with the 2-byte bug.)
            rec = ndr.format.spikegadgets.read_rec_trodeChannels( ...
                testCase.RecFile, num2str(testCase.C), 1, testCase.SR, ...
                num2str(testCase.H), 1001, 2000);
            expected = double(int16(1001:2000)).' * 12780 / 65536;
            testCase.verifyEqual(rec(:), expected, 'AbsTol', 1e-9);
        end

        function testTrodeTimestampsHonorS0(testCase)
            % Trode timestamps must start at (s0-1)/SR, not 0.
            s0 = 1001;
            [~, ts] = ndr.format.spikegadgets.read_rec_trodeChannels( ...
                testCase.RecFile, num2str(testCase.C), 1, testCase.SR, ...
                num2str(testCase.H), s0, 2000);
            testCase.verifyEqual(ts(1), (s0-1)/testCase.SR, 'AbsTol', 1e-12);
            testCase.verifyEqual(ts(:).', ((s0-1):1999)/testCase.SR, 'AbsTol', 1e-12);
        end
    end

    methods (Static)
        function writeSyntheticRec(path, hdr, ts, chan)
            % Write '</Configuration>' + 1 pad byte, then P packets of
            % [header int16 | timestamp uint32 | data int16] in native order.
            P = size(hdr,1);
            fid = fopen(path,'w'); % native byte order (matches the readers)
            assert(fid>0, 'could not open synthetic .rec for writing');
            c = onCleanup(@() fclose(fid));
            fwrite(fid, ['</Configuration>' 'P'], 'char');
            for p=1:P
                fwrite(fid, hdr(p,:),  'int16');
                fwrite(fid, ts(p),     'uint32');
                fwrite(fid, chan(p,:), 'int16');
            end
        end
    end
end
