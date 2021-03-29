function test(varargin) % not finished
% ndr.test.reader.spikegadgets_rec.test- test reading using NDR reader with spikegadgets_rec format
%
%
% 

plotit = 1;

assign(varargin{:});

ndr.globals

example_dir = [ndr_globals.path.path filesep 'example_data'];

filename = [example_dir filesep 'example.rec'];

#r = ndr.reader('rec'); % open an rec reader

r = ndr.reader.spikegadgets.spikegadgets_rec(filename);

channels = ndr.reader.spikegadgets.spikegadgets_rec.getchannelsepoch(ndr_reader_base_spikegadgets_obj, epochfiles);




% okay, here demonstrate use of r.readchannels_epochsamples by reading from channel ai1 and read samples 1 through 10000
