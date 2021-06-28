function readertest(varargin)
% ndr.test.reader.spikegadgets_rec.readertest - test reading using NDR reader
%

plotit = 1;

assign(varargin{:});

ndr.globals

example_dir = [ndr_globals.path.path filesep 'example_data'];

filename = [example_dir filesep 'example.rec'];

r = ndr.reader('rec'); % open a rec reader

channels = r.getchannelsepoch({filename});

for i=1:numel(channels),
	disp(['Channel found (' int2str(i) '/' int2str(numel(channels)) '): ' channels(i).name ' of type ' channels(i).type]);
end

% here, use r.readchannel_epochsamples to create variables d and t
epoch_select = 1; % which epoch in the file? For most file systems, there is just 1 epoch per file
channel = 120; % the waveform channel in our example file
d = r.readchannels_epochsamples('analog_in',120,{filename},epoch_select,1,10000);
t = r.readchannels_epochsamples('time',120,{filename},epoch_select,1,10000);

% each epoch begins at T0 and ends at T1
ec = r.epochclock({filename}, epoch_select),
t0_t1 = r.t0_t1({filename}, epoch_select);

disp(['These are the clocktypes we know and how long the recording lasted:'])
for i=1:numel(ec),
	disp(['On clock of type ' ec{i}.ndr_clocktype2char() ' the recording started at ' num2str(t0_t1{i}(1)) ' and ended at ' num2str(t0_t1{i}(2)) '.']);
end;


if plotit,
	figure (1);
	plot(t,d);
	xlabel('Time(s)');
	ylabel('Data values');
	title(['Spikegadgets Example Data']);
end;

