function test(varargin)
% ndr.test.reader.spikegadgets_rec.test- test reading using NDR reader with spikegadgets_rec format
%
%
% 

plotit = 1;

assign(varargin{:});

ndr.globals

example_dir = [ndr_globals.path.path filesep 'example_data'];

filename = [example_dir filesep 'example.rec'];

r = ndr.reader('rec'); % open an rec reader

channels = 

% okay, here demonstrate use of r.readchannels_epochsamples by reading from channel ai1 and read samples 1 through 10000
