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
     % Demonstrate use of r.readchannels_epochsamples by reading channel
     % ai1 and read samples 1 through 1,000
    
end % ndr.test.reader.intan_rhd.test