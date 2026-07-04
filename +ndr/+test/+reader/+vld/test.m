function test(filename, varargin)
% ndr.test.reader.vld.test - Test reading VH Lab LabView (.vld/.vlh) files
%
%   ndr.test.reader.vld.test(FILENAME)
%
%   Opens the VH Lab LabView data file FILENAME (extension '.vld', with a
%   matching '.vlh' header file in the same directory) using an
%   ndr.reader('vld') object, lists its channels, reads a sample of data
%   from the first analog input channel, and reports the epoch timing.
%
%   If FILENAME is not provided, a small synthetic recording is generated
%   and verified using ndr.test.reader.vld.readertest.
%
%  See also: ndr.reader.vld, ndr.test.reader.vld.readertest

    plotit = 1;

    ndr.data.assign(varargin{:});

    ndr.globals

    if nargin<1 || isempty(filename),
        % No file provided: run the self-contained round-trip test.
        ndr.test.reader.vld.readertest(plotit);
        return;
    end;

    r = ndr.reader('vld'); % Open a VH Lab LabView reader

    channels = r.getchannelsepoch({filename});

    for i=1:numel(channels),
        disp(['Channel found (' int2str(i) '/' int2str(numel(channels)) '): ' channels(i).name ' of type ' channels(i).type]);
    end

    epoch_select = 1; % Which epoch in the file? There is 1 epoch per file for this format.

    % Read the first analog input channel and the corresponding time base.
    t0t1 = r.t0_t1({filename}, epoch_select);
    ec = r.epochclock({filename},epoch_select);

    d = r.readchannels_epochsamples('ai',1,{filename},epoch_select,1,Inf);
    t = r.readchannels_epochsamples('time',1,{filename},epoch_select,1,Inf);

    disp(['These are the clocktypes we know and how long the recording lasted:']);
    for i=1:numel(ec),
        disp(['On clock of type ' ec{i}.ndr_clocktype2char() ' the recording started at ' num2str(t0t1{i}(1)) ' and ended at ' num2str(t0t1{i}(2)) '.']);
    end;

    if plotit,
        figure;
        plot(t,d);
        xlabel('Time (s)');
        ylabel('Data values');
        title('VH Lab LabView (vld) example data');
    end;

end % ndr.test.reader.vld.test
