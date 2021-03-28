function test(varargin)
% ndr.test.reader.ced_smr.test- test reading using NDR reader with CED SOMSMR format
%
%
% 

plotit = 1;

assign(varargin{:});

ndr.globals

example_dir = [ndr_globals.path.path filesep 'example_data'];

filename = [example_dir filesep 'example.smr'];

r = ndr.reader('smr'); % open an smr reader

channels = r.getchannelsepoch({filename});

for i=1:numel(channels),
	disp(['Channel found (' int2str(i) '/' int2str(numel(channels)) '): ' channels(i).name ' of type ' channels(i).type]);
end

if plotit,
	figure (1);
	plot(t,d);
	xlabel('Time(s)');
	ylabel('Data values');
	title(['CED example data']);
end;

 % okay, here demonstrate use of r.readchannels_epochsamples by reading from channel ai1 and read samples 1 through 10000
