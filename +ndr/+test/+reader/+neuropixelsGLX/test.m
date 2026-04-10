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
    % Sync channel is a 16-bit digital word (packed digital lines), not 0/1.
    % Use a ramping pattern that exercises multiple bits to confirm the full
    % 16-bit value is preserved end-to-end.
    sync_data = int16(mod((0:nSamples-1), 2^15));
    data(:, nTotalChans) = sync_data(:);

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

    % Read the digital (sync) channel through the high-level read() API.
    % This is the code path that previously returned [] because
    % ndr.reader.read() routed 'digital_in' to readevents_epochsamples
    % (which is abstract for this format).
    t0 = 0;
    t1 = (nSamples-1) / SR;
    [d_di, t_di] = r.read({metafile}, 'di1', 't0', t0, 't1', t1);
    disp(['Read ' int2str(size(d_di, 1)) ' samples from channel di1 via r.read().']);
    assert(~isempty(d_di), 'Digital read returned empty data.');
    assert(~isempty(t_di), 'Digital read returned empty time.');
    assert(size(d_di, 1) == nSamples, ...
        sprintf('Digital sample count mismatch: got %d, expected %d.', ...
        size(d_di, 1), nSamples));
    % The full 16-bit word must be preserved (not collapsed to 0/1).
    di_error = max(abs(double(d_di) - double(sync_data(:))));
    disp(['Max digital error vs expected: ' num2str(di_error)]);
    assert(di_error == 0, 'Digital (16-bit) word mismatch detected!');

    disp('All checks passed.');

    if plotit
        figure(1);
        plot(t, double(d));
        xlabel('Time (s)');
        ylabel('Raw int16 value');
        title('Neuropixels SpikeGLX Test Data — Channel ai1');
    end

end
