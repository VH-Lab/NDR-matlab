function test(varargin)
% ndr.test.format.spikegadgets.test - test reading from SpikeGadgets format
%
%
% 

plotit = 0;

assign(varargin{:});


ndr.globals

example_dir = [ndr_globals.path.path filesep 'example_data']; % error: Dot indexing is not supported for variables of this type

filename = [example_dir filesep 'example.rec'];

h = ndr.format.spikegadgets.read_rec_config(filename);

disp(['Read header file. Header entries are as follows:']);

h,

t1 = 1 * eval(h.samplingRate);  % index number of sample at time 1 s after the first sample

[data, time] = ndr.format.spikegadgets.read_rec_trodeChannels(filename,h.numChannels, 1, eval(h.samplingRate), h.headerSize,1,t1);
  
  
if plotit,
	figure;
	plot(time,data);
	xlabel('Time(s)');
	ylabel('Data values');
	title(['SpikeGadgets test data']);
end;
