function readertest(plotit)
% READERTEST - Test the functionality of the vld ndr.reader.read function
%
%   ndr.test.reader.vld.readertest()
%   ndr.test.reader.vld.readertest(PLOTIT)
%
%   Writes a small synthetic VH Lab LabView (.vld/.vlh) recording to a
%   temporary directory, reads it back with ndr.reader('vld'), and checks
%   that the recovered data and time base match what was written. If PLOTIT
%   is 1 (default 0), the recovered channel is plotted.
%
%   The synthetic file is multiplexed, int16 precision with a Scale factor,
%   and mirrors the layout produced by
%   vlt.file.custom_file_formats.writevhlvtestfile: channel c contains the
%   ramp c + (0:0.001:...) across two chunks.
%
% See also: ndr.reader, ndr.format.vld.readvhlvheaderfile,
%   ndr.format.vld.readvhlvdatafile

    if nargin<1,
        plotit = 0;
    end;

    num_channels = 4;
    samplerate = 100;
    samples_per_chunk = 100;
    scale = num_channels+1;
    chunk_total = 2;

    % 1) write a synthetic test recording to a temporary location

    tempdir_here = tempname();
    mkdir(tempdir_here);
    cleanupObj = onCleanup(@() rmdir(tempdir_here,'s'));

    basename = 'vld_readertest';
    vldfile = fullfile(tempdir_here,[basename '.vld']);
    vlhfile = fullfile(tempdir_here,[basename '.vlh']);

    header.ChannelString = ['channels 1:' int2str(num_channels)];
    header.NumChans = num_channels;
    header.SamplingRate = samplerate;
    header.SamplesPerChunk = samples_per_chunk;
    header.Scale = scale;
    header.precision = 'int16';
    header.Multiplexed = 1;

    % write the .vlh header text file (field:\tvalue per line)
    fn = fieldnames(header);
    fid_h = fopen(vlhfile,'wt');
    if fid_h<0,
        error(['Could not open ' vlhfile ' for writing.']);
    end;
    for i=1:numel(fn),
        val = header.(fn{i});
        if ischar(val),
            fprintf(fid_h,[fn{i} ':\t' val '\n']);
        else,
            fprintf(fid_h,[fn{i} ':\t' mat2str(val) '\n']);
        end;
    end;
    fclose(fid_h);

    output_maxint = 2^15 - 1;

    % build the full expected data matrix (samples x channels)
    Dexpected = [];
    fid_out = fopen(vldfile,'w','ieee-be');
    if fid_out<0,
        error(['Could not open ' vldfile ' for writing.']);
    end;
    for c=1:chunk_total,
        D = repmat((1:num_channels)',1,samples_per_chunk)+(c-1)*(0.1)+...
            repmat((0:0.001:0.001*(samples_per_chunk-1)),num_channels,1);
        Dout = int16(D*output_maxint/scale);
        fwrite(fid_out,Dout,'int16',0,'ieee-be');
        % what we expect to read back is the int16-quantized, rescaled value
        Dexpected = [Dexpected ; single(Dout')*scale/output_maxint];
    end;
    fclose(fid_out);

    total_samples = chunk_total*samples_per_chunk;

    % 2) read it back through the NDR reader

    r = ndr.reader('vld');

    % check channel listing
    channels = r.getchannelsepoch({vldfile});
    assert(numel(channels)==num_channels+1, ...
        'Expected %d channels (time + %d analog_in), got %d.', ...
        num_channels+1, num_channels, numel(channels));
    assert(strcmp(channels(1).type,'time'),'First channel should be the time channel.');

    % check t0_t1
    t0t1 = r.t0_t1({vldfile});
    assert(abs(t0t1{1}(1))<1e-9,'t0 should be 0.');
    assert(abs(t0t1{1}(2)-(total_samples-1)/samplerate)<1e-9,'t1 mismatch.');

    % read every analog channel across the whole recording
    for c=1:num_channels,
        [d,t] = r.read({vldfile},['ai' int2str(c)]);
        assert(numel(d)==total_samples,'Channel %d: expected %d samples, got %d.',c,total_samples,numel(d));
        assert(numel(t)==total_samples,'Channel %d: expected %d time points, got %d.',c,total_samples,numel(t));
        err = max(abs(double(d(:))-double(Dexpected(:,c))));
        assert(err<1e-3,'Channel %d: data mismatch (max err %g).',c,err);
        % time base: sample 1 at t==0, spaced 1/samplerate
        texpected = (0:total_samples-1)'/samplerate;
        assert(max(abs(double(t(:))-texpected))<1e-9,'Channel %d: time base mismatch.',c);
    end;

    % read a sub-range using samples
    [d2,t2] = r.read({vldfile},'ai2','useSamples',1,'s0',10,'s1',20);
    assert(numel(d2)==11,'Sub-range read should return 11 samples, got %d.',numel(d2));
    assert(max(abs(double(d2(:))-double(Dexpected(10:20,2))))<1e-3,'Sub-range data mismatch.');
    assert(max(abs(double(t2(:))-((10:20)'-1)/samplerate))<1e-9,'Sub-range time mismatch.');

    disp('ndr.test.reader.vld.readertest: all checks passed.');

    if plotit,
        [d,t] = r.read({vldfile},'ai1');
        figure;
        plot(t,d);
        xlabel('Time (s)');
        ylabel('Value');
        title('ndr.reader vld readertest: ai1');
    end;

end % ndr.test.reader.vld.readertest
