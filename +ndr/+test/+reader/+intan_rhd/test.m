function test(varargin)
% ndr.test.reader.intan_rhd.test - Test reading using Neuroscience Data Reader with Intan
% Technologies .RHD file format
%
%  See also: ndr.reader.intan_rhd
%
    plotit = 1;
    
    assign(varargin{:});
    
    
    ndr.globals
    
    example_dir = [ndr_globals.path.path filesep 'example_data'];
    
    filename = [example_dir filesep 'example.rhd'];
    
    r = ndr.reader('intan'); % Open a .RHD reader
    
    channels = r.getchannelsepoch({filename});
    
    for i=1:numel(channels),
        disp(['Channel found (' int2str(i) '/' int2str(numel(channels)) '): ' channels(i).name ' of type ' channels(i).type]);
    end
    
    % Demonstrate use of r.readchannels_epochsamples by reading channel ai1 and read samples 1 through 10,000
    % Use r.readchannels_epochsamples to create a variable d, and t
    epoch_select = 1; % Which epoch in the file? For most file systems, there is just 1 epoch per file
    channel = 32; % The waveform channel in our example file
    d = r.readchannels_epochsamples('ai',32,{filename},epoch_select,1,10000);
    t = r.readchannels_epochsamples('time',32,{filename},epoch_select,1,10000);
    
    % Each epoch begins at t0 and ends at t1
    ec = r.epochclock({filename},epoch_select),
    t0t1 = r.t0_t1({filename}, epoch_select);
    
    disp(['These are the clocktypes we know and how long the recording lasted:'])
    for i=1:numel(ec),
        disp(['On clock of type ' ec{i}.ndr_clocktype2char() ' the recording started at ' num2str(t0t1{i}(1)) ' and ended at ' num2str(t0t1{i}(2)) '.']);
    end;
    
    if plotit,
        figure(1);
        plot(t,d);
        xlabel('Time (s)');
        ylabel('Data values');
        title(['Intan example data']);
    end;
    
end % ndr.test.reader.intan_rhd.test