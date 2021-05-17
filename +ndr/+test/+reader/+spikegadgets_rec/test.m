function test(varargin)
% ndr.test.reader.spikegadgets_rec.test- test reading using NDR reader with spikegadgets_rec format
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
 
 epoch_select = 1; 
 channel = 120; 
 
 data = r.readchannels_epochsamples('analog_in',channel,{filename},epoch_select,1,10000);
 time = r.readchannels_epochsamples('time',channel,{filename},epoch_select,1,10000);

 % each epoch begins at T0 and ends at T1
 ec = r.epochclock({filename}, epoch_select);
 t0t1 = r.t0_t1({filename}, epoch_select);

 disp(['These are the clocktypes we know and how long the recording lasted:'])
 	for i=1:numel(ec),
		disp(['On clock of type ' ec{i}.ndr_clocktype2char() ' the recording started at ' num2str(t0t1{i}(1)) ' and ended at ' num2str(t0t1{i}(2)) '.']);
	end;
 
 channelstruct = r.ndr_reader_base.daqchannels2internalchannels('ai', channel, {filename}, epoch_select);
 
 % Unrecognized method, property, or field 'daqchannels2internalchannels' for class 'ndr.reader'.
 
 channelstruct % add function as base results in empty struct array 
 

if plotit, 
	figure;
	plot(time,data);
	xlabel('Time(s)');
	ylabel('Data values');
	title(['SpikeGadgets Example Data']);
end;
