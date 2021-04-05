function test(varargin) % not finished
% ndr.test.reader.spikegadgets_rec.test- test reading using NDR reader with spikegadgets_rec format
%
%
% 

plotit = 1;

assign(varargin{:});

ndr.globals

example_dir = [ndr_globals.path.path filesep 'example_data'];
% same as format.test: Dot indexing is not supported for variables of this type.

filename = [example_dir filesep 'example.rec'];

r = ndr.reader('rec'); % open an rec reader


channels = r.getchannelsepoch({filename});

for i=1:numel(channels),
  
  disp(['Channel found (' int2str(i) '/' int2str(numel(channels)) '): ' channels(i).name ' of type ' channels(i).type]);

end


% okay, here demonstrate use of r.readchannels_epochsamples by reading from channel ai1 and read samples 1 through 10000
 
 
 data = r.readchannels_epochsamples( {filename}, 21, channels, 1,10000)
 time = r.readchannels_epochsamples(filename,'ai',21,1,10000)

if plotit,
	figure (1);
	plot(time,data);
	xlabel('Time(s)');
	ylabel('Data values');
	title(['SpikeGadgets example data']);
end;
