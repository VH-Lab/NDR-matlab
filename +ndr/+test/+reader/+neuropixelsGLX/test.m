function test(varargin)
%NDR.TEST.READER.NEUROPIXELSGLX.TEST - Test reading using NDR reader for Neuropixels SpikeGLX
%
%   ndr.test.reader.neuropixelsGLX.test()
%   ndr.test.reader.neuropixelsGLX.test('plotit', 0)
%
%   Creates a small synthetic Neuropixels SpikeGLX dataset (AP-band binary
%   and metadata files) in a temporary directory, then exercises the
%   ndr.reader.neuropixelsGLX reader to verify correct behavior.
%
%   This test creates files with 16 neural channels + 1 sync channel to
%   keep the test data small while still exercising all reader functionality.
%
%   Optional arguments (name/value):
%       plotit (1) - If 1, plot the first channel's data.
%
%   See also: ndr.reader.neuropixelsGLX, ndr.format.neuropixelsGLX.header

    plotit = 1;
    assign(varargin{:});

    disp('--- ndr.test.reader.neuropixelsGLX.test ---');

    % Parameters for synthetic data
    SR = 30000;
    nNeuralChans = 16;
    nTotalChans = nNeuralChans + 1;  % +1 sync
    nSamples = 3000;  % 0.1 seconds

    % Create temp directory
    tempdir_path = fullfile(tempdir, ['ndr_npx_test_' num2str(randi(1e6))]);
    subdir = fullfile(tempdir_path, 'test_g0', 'test_g0_imec0');
    mkdir(subdir);
    cleanup = onCleanup(@() rmdir(tempdir_path, 's'));

    metafile = fullfile(subdir, 'test_g0_t0.imec0.ap.meta');
    binfile = fullfile(subdir, 'test_g0_t0.imec0.ap.bin');

    % Generate data: channel i has a sine wave at i Hz
    t_vec = (0:nSamples-1)' / SR;
    data = zeros(nSamples, nTotalChans, 'int16');
    for c = 1:nNeuralChans
        data(:, c) = int16(round(500 * sin(2 * pi * c * t_vec)));
    end
    % Sync channel is a 16-bit packed digital word. Each bit is exposed as
    % a separate digital line (di1..di16). Use a counter pattern that
    % exercises bits 0..14 (mod 2^15 keeps values non-negative so the int16
    % representation is unambiguous).
    sync_pattern = int16(mod((0:nSamples-1), 2^15));
    data(:, nTotalChans) = sync_pattern(:);

    % Write binary
    fid = fopen(binfile, 'w', 'ieee-le');
    fwrite(fid, reshape(data', 1, []), 'int16');
    fclose(fid);

    % Write meta
    fid = fopen(metafile, 'w');
    fprintf(fid, 'imSampRate=%g\n', SR);
    fprintf(fid, 'nSavedChans=%d\n', nTotalChans);
    fprintf(fid, 'snsApLfSy=%d,0,1\n', nNeuralChans);
    fprintf(fid, 'snsSaveChanSubset=all\n');
    fprintf(fid, 'fileSizeBytes=%d\n', nSamples * nTotalChans * 2);
    fprintf(fid, 'fileTimeSecs=%.6f\n', nSamples / SR);
    fprintf(fid, 'imAiRangeMax=0.6\n');
    fprintf(fid, 'imAiRangeMin=-0.6\n');
    fprintf(fid, 'imMaxInt=512\n');
    fprintf(fid, 'imDatPrb_type=0\n');
    fprintf(fid, 'imDatPrb_sn=0000000000\n');
    fprintf(fid, 'typeThis=imec\n');
    fclose(fid);

    % Create reader
    r = ndr.reader('neuropixelsGLX');
    disp(['Reader class: ' class(r.ndr_reader_base)]);

    % List channels
    channels = r.getchannelsepoch({metafile}, 1);
    disp(['Found ' int2str(numel(channels)) ' channels:']);
    for i = 1:numel(channels)
        disp(['  ' channels(i).name ' (' channels(i).type ')']);
    end

    % Read data
    epoch_select = 1;
    d = r.readchannels_epochsamples('analog_in', 1, {metafile}, epoch_select, 1, nSamples);
    t = r.readchannels_epochsamples('time', 1, {metafile}, epoch_select, 1, nSamples);

    disp(['Read ' int2str(size(d, 1)) ' samples from channel ai1.']);
    disp(['Time range: ' num2str(t(1)) ' to ' num2str(t(end)) ' seconds.']);

    % Check epoch info
    ec = r.epochclock({metafile}, epoch_select);
    t0t1 = r.t0_t1({metafile}, epoch_select);

    for i = 1:numel(ec)
        disp(['Clock type: ' ec{i}.ndr_clocktype2char() ...
            ', t0=' num2str(t0t1{i}(1)) ', t1=' num2str(t0t1{i}(2))]);
    end

    % Check sample rate
    sr = r.samplerate({metafile}, epoch_select, 'analog_in', 1);
    disp(['Sample rate: ' num2str(sr) ' Hz']);

    % Verify data matches
    expected = int16(round(500 * sin(2 * pi * 1 * t_vec)));
    max_error = max(abs(double(d) - double(expected)));
    disp(['Max error vs expected: ' num2str(max_error)]);
    assert(max_error == 0, 'Data mismatch detected!');

    % Verify that the IMEC sync word is exposed as 16 single-bit digital
    % lines (di1..di16), one per bit of the int16 sync column.
    di_idx = find(strcmp({channels.type}, 'digital_in'));
    assert(numel(di_idx) == 16, ...
        sprintf('Expected 16 IMEC digital lines, got %d.', numel(di_idx)));

    % Read individual digital lines through the high-level read() API.
    % This is the code path that previously returned [] because
    % ndr.reader.read() routed 'digital_in' to readevents_epochsamples
    % (which is abstract for this format).
    t1_end = (nSamples-1) / SR;
    [d_di1, t_di] = r.read({metafile}, 'di1', 't0', 0, 't1', t1_end);
    disp(['Read ' int2str(size(d_di1, 1)) ' samples from channel di1 via r.read().']);
    assert(~isempty(d_di1), 'Digital di1 read returned empty data.');
    assert(~isempty(t_di), 'Digital di1 read returned empty time.');
    assert(size(d_di1, 1) == nSamples, ...
        sprintf('Digital sample count mismatch: got %d, expected %d.', ...
        size(d_di1, 1), nSamples));
    % di1 is bit 0 of the sync word (alternates 0,1,0,1,...).
    expected_di1 = int16(bitget(sync_pattern(:), 1));
    assert(isequal(d_di1, expected_di1), 'di1 (bit 0) extraction mismatch.');

    % di8 is bit 7 of the sync word.
    [d_di8, ~] = r.read({metafile}, 'di8', 't0', 0, 't1', t1_end);
    expected_di8 = int16(bitget(sync_pattern(:), 8));
    assert(isequal(d_di8, expected_di8), 'di8 (bit 7) extraction mismatch.');

    % di12 is bit 11 of the sync word (2^11 = 2048; the pattern reaches
    % 2999 so this bit is non-trivially exercised).
    [d_di12, ~] = r.read({metafile}, 'di12', 't0', 0, 't1', t1_end);
    expected_di12 = int16(bitget(sync_pattern(:), 12));
    assert(any(expected_di12 ~= 0), ...
        'Test pattern should exercise bit 11; check sync_pattern.');
    assert(isequal(d_di12, expected_di12), 'di12 (bit 11) extraction mismatch.');

    % === NIDQ format test ===
    % Mirrors the user-reported configuration: snsMnMaXaDw=0,0,8,1 with
    % niXDBytes1=1, so 8 analog inputs plus 8 digital lines packed into
    % the low byte of a single int16 DW column.
    disp('--- NIDQ format test ---');

    nXA = 8;
    nDW = 1;
    nNidqChans = nXA + nDW;
    nNidqSamples = 500;
    SR_ni = 10593.220339;

    nidq_subdir = fullfile(tempdir_path, 'nidq_g0');
    mkdir(nidq_subdir);
    nidq_metafile = fullfile(nidq_subdir, 'nidq_g0_t0.nidq.meta');
    nidq_binfile  = fullfile(nidq_subdir, 'nidq_g0_t0.nidq.bin');

    % Build data: XA0..XA7 sine waves + DW column with an 8-bit pattern.
    ni_data = zeros(nNidqSamples, nNidqChans, 'int16');
    t_vec_ni = (0:nNidqSamples-1)' / SR_ni;
    for c = 1:nXA
        ni_data(:, c) = int16(round(1000 * sin(2 * pi * c * t_vec_ni)));
    end
    ni_sync = int16(mod((0:nNidqSamples-1), 2^8));  % low byte: 0..255
    ni_data(:, end) = ni_sync(:);

    fid = fopen(nidq_binfile, 'w', 'ieee-le');
    fwrite(fid, reshape(ni_data', 1, []), 'int16');
    fclose(fid);

    fid = fopen(nidq_metafile, 'w');
    fprintf(fid, 'niSampRate=%.6f\n', SR_ni);
    fprintf(fid, 'nSavedChans=%d\n', nNidqChans);
    fprintf(fid, 'snsMnMaXaDw=0,0,%d,%d\n', nXA, nDW);
    fprintf(fid, 'snsSaveChanSubset=all\n');
    fprintf(fid, 'fileSizeBytes=%d\n', nNidqSamples * nNidqChans * 2);
    fprintf(fid, 'fileTimeSecs=%.6f\n', nNidqSamples / SR_ni);
    fprintf(fid, 'niAiRangeMax=5\n');
    fprintf(fid, 'niAiRangeMin=-5\n');
    fprintf(fid, 'niMaxInt=32768\n');
    fprintf(fid, 'niXDBytes1=1\n');
    fprintf(fid, 'niXDChans1=0:7\n');
    fprintf(fid, 'niXAChans1=0:7\n');
    fprintf(fid, 'typeThis=nidq\n');
    fclose(fid);

    r_ni = ndr.reader('neuropixelsGLX');
    ni_channels = r_ni.getchannelsepoch({nidq_metafile}, 1);
    ni_di_count = sum(strcmp({ni_channels.type}, 'digital_in'));
    assert(ni_di_count == 8, ...
        sprintf('Expected 8 NIDQ digital lines (niXDBytes1=1), got %d.', ...
        ni_di_count));
    ni_ai_count = sum(strcmp({ni_channels.type}, 'analog_in'));
    assert(ni_ai_count == nXA, ...
        sprintf('Expected %d NIDQ analog lines, got %d.', nXA, ni_ai_count));

    % Read di1 via r.read() — the exact call the user reported failing.
    t1_ni = (nNidqSamples-1) / SR_ni;
    [d_ni_di1, t_ni_di1] = r_ni.read({nidq_metafile}, 'di1', 't0', 0, 't1', t1_ni);
    assert(~isempty(d_ni_di1), 'NIDQ di1 returned empty data (user-reported bug).');
    assert(~isempty(t_ni_di1), 'NIDQ di1 returned empty time.');
    assert(size(d_ni_di1, 1) == nNidqSamples, ...
        sprintf('NIDQ di1 sample count mismatch: got %d, expected %d.', ...
        size(d_ni_di1, 1), nNidqSamples));
    expected_ni_di1 = int16(bitget(ni_sync(:), 1));
    assert(isequal(d_ni_di1, expected_ni_di1), 'NIDQ di1 (bit 0) mismatch.');

    % Read di8 (bit 7, the high bit of the byte).
    [d_ni_di8, ~] = r_ni.read({nidq_metafile}, 'di8', 't0', 0, 't1', t1_ni);
    expected_ni_di8 = int16(bitget(ni_sync(:), 8));
    assert(isequal(d_ni_di8, expected_ni_di8), 'NIDQ di8 (bit 7) mismatch.');

    % di9 must be out of range for an 8-line NIDQ configuration. Call
    % readchannels_epochsamples directly because the high-level read()
    % would fail earlier at channel-name lookup (di9 isn't listed).
    threw = false;
    try
        r_ni.readchannels_epochsamples('digital_in', 9, ...
            {nidq_metafile}, 1, 1, 10);
    catch ME
        threw = strcmp(ME.identifier, ...
            'ndr:reader:neuropixelsGLX:DigitalLineOutOfRange');
    end
    assert(threw, 'Expected DigitalLineOutOfRange error for line 9 in 8-line NIDQ.');

    disp('NIDQ digital line read: OK.');

    disp('All checks passed.');

    if plotit
        figure(1);
        plot(t, double(d));
        xlabel('Time (s)');
        ylabel('Raw int16 value');
        title('Neuropixels SpikeGLX Test Data — Channel ai1');
    end

end
